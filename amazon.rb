module AmazonAPI

  ###############################
  # Reader and Writer
  ###############################

  module Reader

    def reader
      # if text read ...
    end

    def m_reader(path)
      f = open(path, "r")
      data = Marshal.load(f)
      f.close
      return data
    end

  end

  module Writer

    def writer(path, data)
      File.open(path, 'w:utf-8'){|f| f.print data}
    end

    def m_writer(path, data)
      f = open(path, "w")
      Marshal.dump(data, f)
      f.close
    end

  end

  module ReaderWriter
    include Reader
    include Writer
  end

  ###############################
  # AwsItem
  ###############################

  class AwsItem

    def initialize(h)
      @h = h
      @created = nil
      # amazon data
      @productgroup = nil
      @ean = nil
      @title = nil
      @artist = nil
      @author = nil
      @price = nil
      @mediumimage = nil
      @detailpageurl = nil
      # if given amazon hash data
      set_up if @h
    end

    attr_reader :ean, :title, :h

    def to_s
      ary = []
      @created = Time.parse(@created).strftime("%Y/%m/%d")
      to_a.each{|x| ary << instance_variable_get(x).to_s}
      printf "\t[%-13s][%-5s][%s] %s\s|\s%s\n" % ary
    end

    def to_a
      if @h["ProductGroup"] == "Book"
        [:@ean, :@productgroup, :@created, :@title, :@author]
      else
        [:@ean, :@productgroup, :@created, :@title, :@artist]
      end
    end

    def to_s_txt
      str = String.new("").encode("UTF-8")
      to_a.each{|x|
        i = x.to_s.gsub("@","--") 
        v = instance_variable_get(x).to_s
        str << i + "\n" + v + "\n"
      }
      return str
    end

    def set_up
      @h.each{|k,v| set_ins(k, v)}
      return self
    end

    private

    def set_ins(x, v)
      i = "@#{x}".downcase.to_sym
      self.instance_variable_set(i, v) if i_defined?(i)
    end

    def i_defined?(i)
      self.instance_variable_defined?(i)
    end

  end

  ###############################
  # Aws Data
  ###############################

  class AwsData

    include ReaderWriter

    def initialize(data=nil)
      @data = data
      @list = Hash.new
      list_load
    end

    # new item add to the list.
    def add_data
      return nil unless @data
      @data[:created] = Time.now.to_s
      @item = AwsItem.new(@data)
      list_add
      list_save
      item_save
    end
    # print list
    def view(num=nil)
      num = 5 unless num
      return nil if @list.empty?
      @ary = [] 
      @list.values.sort_by{|v| v[:created].to_s}.reverse[0..num.to_i].each{|v| @ary << AwsItem.new(v).set_up}
      item_view
    end
    # search keyword in title or artist, author, lavel, publisher, etc...
    def lookup(w)
      @ary = Array.new
      search_key(w)
      search_val(w) if @ary.empty?
      return puts "not found\n" if @ary.empty?
      item_view
    end
    # print all isbn
    def view_isbnlist
      @list.keys.each{|k| print "#{k}\n"}
    end

    private

    def search_key(w)
      @ary << AwsItem.new(@list[w]).set_up if @list.key?(w)
    end

    def search_val(w)
      @list.values.select{|h|
        hit = h.values.select{|x| x.downcase.include?(w.downcase)}
        next if hit.empty?
        @ary << AwsItem.new(h).set_up
      }
      return @ary
    end

    def choose_item
      return @ary[0] if @ary.size == 1
      no = BaseMessage.new.message("Select", @ary.size)
      return nil unless no
      return @ary[no-1]
    end

    def choose_option
      o = BaseMessage.new.message("SelectOption [o/i/r/n]", false)
      return nil unless o
      item_open if o == "o"
      item_detail if o == "i"
      item_delete if o == "r"
    end

    def item_txt_path
      File.join(dir_text, @item.ean + ".txt")
    end

    def item_save
      return nil if FileTest.exist?(item_txt_path)
      data = AwsItem.new(@data).to_s_txt
      writer(item_txt_path, data)
    end

    def item_view
      @ary.each_with_index{|v,i|
        print (i + 1) ; v.to_s
      }
      @item = choose_item
      choose_option if @item
    end

    def item_delete
      @list.delete(@item.ean)
      m_writer(db_path, @list)
      path = item_txt_path
      trash = File.join(dir_text, "removed-" + @item.ean)
      File.rename(path, trash)
      print "Removed: #{@item.title}\n"
      print "Saved: #{db_path}\n"
    end

    def item_open
      return nil unless FileTest.exist?(item_txt_path)
      # your editor
      exec "vim #{item_txt_path}"
    end

    def item_detail
      @item.h.each{|k,v| print "#{k}: #{v}\n" }
    end

    def list_load
      return nil unless FileTest.exist?(db_path)
      @list = m_reader(db_path)
    end

    def list_add
      @list[@item.ean] = @data
      print "Added: #{@data["Title"]}\n"
    end

    def list_save
      m_writer(db_path, @list)
      print "Saved: #{db_path}\n"
    end

    def dir_current
      File.dirname(File.expand_path($PROGRAM_NAME))
    end

    def dir_text
      File.join(dir_current, 'data', 'text')
    end

    def db_path
      File.join(dir_current, 'data', 'db-data')
    end

  end

  ###############################
  # HMAC Module
  ###############################

  module HMAC

    IPAD = "\x36" * 64
    OPAD = "\x5c" * 64

    module_function

    def sha256(key, message)
      ipad = IPAD.each_byte.to_a
      opad = OPAD.each_byte.to_a
      akey = key.each_byte.to_a

      ikey = ipad
      okey = opad
      key.size.times{|i|
        ikey[i] = akey[i] ^ ipad[i]
        okey[i] = akey[i] ^ opad[i]
      }
      ik, ok  = ikey.pack("C*"), okey.pack("C*")
      value = Digest::SHA256.digest(ik + message)
      value = Digest::SHA256.digest(ok + value)
    end

  end

  ###############################
  # Aws Access
  ###############################

  class AmazonAccess

    include $MYCONF

    def initialize(ean=nil)
      @aws_uri = URI.parse(jp_url)
      @ean = ean
    end

    def base
      return nil unless @ean
      return nil unless ean_check
      seturi
      xml = access
      data = AwsXML.new(xml, amazon_id).base if xml
      AwsData.new(data).add_data if data
    end

    private

    def ean_check
      return nil if @ean.size < 9 or @ean.size > 13
      return nil if m = /\D/.match(@ean)
      return true
    end

    def escape(str)
      str.gsub(/([^ a-zA-Z0-9_.-]+)/){'%' + $1.unpack('H2' * $1.bytesize).join('%').upcase}.tr(' ', '+')
    end

    def local_utc
      t = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      escape(t)
    end

    def seturi
      @aws_uri.path = '/onca/xml'
      q = [
        "Service=AWSECommerceService",
        "AWSAccessKeyId=#{amazon_key}",
        "Operation=ItemLookup",
        "ItemId=#{@ean}",
        "ResponseGroup=Medium",
        "Timestamp=#{local_utc}",
        "Version=2009-03-31"
      ]
      case @ean.size
      when 10
        q << ["SearchIndex=Books" ,"IdType=ISBN"]  # Book isbn 10
      when 12
        q << ["SearchIndex=Music", "IdType=EAN"]   # Not japanese CD
      when 13                                      # Book isbn 13
        if m = /^978|^491/.match(@ean)
          q << ["SearchIndex=Books" ,"IdType=ISBN"]
        elsif m = /^458/.match(@ean)               # japanese DVD
          q << ["SearchIndex=DVD", "IdType=EAN"]
        else
          q << ["SearchIndex=Music", "IdType=EAN"] # Japanese CD
        end
      end
      req = q.flatten.sort.join("&")
      msg = ["GET", @aws_uri.host, @aws_uri.path, req].join("\n")
      hash = HMAC::sha256(amazon_sec, msg)
      mh = [hash].pack("m").chomp 
      sig = escape(mh)
      @aws_uri.query = "#{req}&Signature=#{sig}"
      return @aws_uri
    end

    def access
      host = @aws_uri.host
      request = @aws_uri.request_uri
      doc = nil
      begin
        Net::HTTP.start(host){|http|
          response = http.get(request)
          doc = response.body
        }
      rescue SocketError
        return print "SocketError \n"
      end
      v = doc.valid_encoding?
      return print "Not ValidXML\n" unless v
      return doc
    end

  end

  ###############################
  # Aws XML
  ###############################

  class AwsXML

    def initialize(xml, aws_id=nil)
      if xml
        # reference: http://yugui.jp/articles/850
        # ustr = xml.force_encoding("UTF-8")
        unless xml.include?("Error")
          @xml = REXML::Document.new(xml)
        else
          print "ErrorXML \n"
        end
      end
      @h = Hash.new
      @aws_id = aws_id
    end

    def base
      return nil unless @xml
      getelement
      set_data
      return @h
    end

    private

    def getelement
      ei = @xml.root.elements["Items/Item"]
      @attrib = get(ei, "ItemAttributes")
      @img = get(ei, "MediumImage")
      @url = get(ei, "DetailPageURL")
      @rank = get(ei, "SalesRank").text
    end

    def set_data
      @attrib.each{|x| @h[x.name] = plural(@attrib, x.name)}
      @h.delete_if{|k,v| v.nil?}
      # setimg
      @h["MediumImage"] = @img.elements["URL"].text unless @img.nil?
      # price
      @h["Price"] = @attrib.elements["ListPrice/FormattedPrice"].text.gsub(/\D/,'')
      #rank
      @h["Rank"] = @rank
      seturl
    end

    def get(ele, str)
      ele.elements[str]
    end

    def plural(ele, str)
      e = ele.get_elements(str)
      case e.size
      when 0
      when 1 then ele.elements[str].text
      else
        @h[str] = e.map{|i| i.text}.join(" / ")
      end
    end

    def seturl
      return nil unless @url
      return nil unless @aws_id
      url = @url.txt + "?tag=#{@aws_id}"
      return url
    end

  end

  ###############################
  # BaseMessage
  ###############################

  class BaseMessage

    def message(str, opt)
      sec = 7
      ans = ''
      begin
        timeout(sec){ans = interactive(str, opt)}
      rescue RuntimeError
        return print "Timeout. #{sec}sec...bye\n"
      rescue SignalException
        return print "\n"
      end
      return ans
    end

    def interactive(mess, opt)
      return false unless $stdin.tty?
      print "#{mess}:\n"
      ans = $stdin.gets.chop
      return false if /^n$|^no$/.match(ans) # n or no == stop
      return false if ans.empty?
      case opt
      when true   # yes or no
        m = /^y$|^yes$/.match(ans)
        return false unless m
        return true
      when false  # return alphabet
        return false if /\d/.match(ans)
        return false if ans.size > 7
        return ans
      else        # return number
        i_ans = ans.to_i
        return false if i_ans > opt
        return false if ans =~ /\D/
        return false unless ans
        return ans.to_i
      end
    end

  end

# end of module AmazonAPI
end

