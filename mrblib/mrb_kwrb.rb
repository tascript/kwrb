class Kwrb
  def self.encode_unsigned_short(val)
    raise 'Falied: value is invalid' if val > 0xffff

    [val.to_i].pack('n*')
  end

  def self.encode(*val)
    val.pack('C*')
  end

  def self.encode_word(val)
    str = val.bytes
    [str.size].pack('n*') + str.pack('C*')
  end

  def self.decode(val)
    val.unpack('C*')
  end
  class Client
    def initialize
      @messeage_id = 0x01
    end

    def self.connect(host, username = nil, password = nil, port = 1883, client_id = 'test_client')
      @client_id = client_id.to_s
      if @client_id.empty? || @client_id.size > 23
        raise 'Failed: client id length is invalid'
      end

      @username = !username.nil? ? username : ''
      @password = !password.nil? ? password : ''

      # connect with host and send payload
      @socket = TCPSocket.open(host, port)
      connect_packet = Kwrb::Packet::Connect.new(@username, @password, @client_id)
      @socket.write connect_packet.data

      # validate connack response
      res = @socket.read
      res_header = res.unpack('C*')[0]
      res_code = res.unpack('C*')[1]
      connack_packet = Kwrb::Packet::Connack.new
      if res_header != connack_packet.header
        raise 'Failed: header is invalid when read connack'
      end
      raise 'Failed: response from blocker is invalid' unless res_code.zero?

      Kwrb::Packet::Connack.validate_code(res_code)

      new
    end

    def publish(topic, message, qos = 0x00)
      raise 'Failed: topic is invalid when publish message' if topic.nil?
      raise 'Failed: message is invalid when publish message' if message.nil?
      if qos.negative? || qos > 0x03
        raise 'Failed: qos is invalid when publish message'
      end

      publish_packet = Kwrb::Packet::Publish.new(topic, qos)
      payload = publish_packet.header.concat message
      @socket.write payload.pack('C*')
      @messeage_id += 1
      res = @socket.read
      case qos
      when 0x00
        return
      when 0x01
        puback_packet = Kwrb::Packet::Puback.new
        if res != puback_packet.header
          raise 'Failed: response from blocker is invalid when get puback'
        end
      when 0x02
        pubrec_packet = Kwrb::Packet::Pubrec.new
        if res != pubrec_packet.header
          raise 'Failed: response from blocker is invalid when get pubrec'
        end

        pubrel_packet = Kwrb::Packet::Pubrel.new
        @socket.write pubrel_packet.header.pack('C*')
        pubcomp_res = @socket.read
        pubcomp_packet = Kwrb::Packet::Pubcomp.new
        if pubcomp_res != pubcomp_packet.header
          raise 'Failed: response from blocker is invalid when get pubcomp'
        end
      else
        raise "Failed: qos flag #{qos} is invalid"
      end
    end

    def subscribe(topic)
      raise 'Failed: topic is invalid when subscribe message' if topic.nil?

      packet = Kwrb::Packet::Subscribe.new
      header = packet.header

      # FIXME: create payload for multiple topics
      payload = [*header, topic.bytes.size, *topic.bytes, 0x02]
      @socket.write payload.pack('C*')

      res = @socket.read
      res_header = res.unpack('C*')[0..2]
      res_payload = res.unpack('C*')[3]
      suback_packet = Kwrb::Packet::Suback.new
      if res_header != suback_packet.header
        raise 'Failed: header is invalid when read suback'
      end
      raise 'Failed: packet is invalid when read suback' if res_payload > 0x03

      puts "Sucscribe is Successful: subscribe #{topic} and qos level is #{res_payload}"
    end

    def unsubscribe
      raise 'Failed: topic is invalid when unsubscribe message' if topic.nil?

      packet = Kwrb::Packet::Unsubscribe.new
      header = packet.header

      # FIXME: create payload for multiple topics
      payload = [*header, 0x00, topic.bytes.size, *topic.bytes, 0x01]
      @socket.write payload.pack('C*')

      res = @socket.read
      res_header = res.unpack('C*')
      unsuback_packet = Kwrb::Packet::Unsuback.new
      if res_header != unsuback_packet.header
        raise 'Failed: header is invalid when read unsuback'
      end

      puts 'Unsubscribe is Successful'
    end

    def pingreq
      packet = Kwrb::Packet::Pingreq.new
      header = packet.header
      @socket.write header.pack('C*')
      res = @socket.read
      pingresp_packet = Kwrb::Packet::Pingresp.new
      if res != pingresp_packet.header
        raise 'Failed: response is invalid when pingresq'
      end
    end

    def disconnect
      packet = Kwrb::Packet::Disconnect.new
      header = packet.header
      @socket.write header.pack('C*')
      @socket.close
      puts 'Disconnect is Successful'
    end
  end

  class Packet
    class Connect
      attr_reader :data
      def initialize(username, password, client_id)
        @type = 0x01
        @protocol = 'MQIsdp'
        @version = 0x03
        @user_flag = !username.nil? ? 1 : 0
        @password_flag = !password.nil? ? 1 : 0
        fixed_header = Kwrb.encode (@type << 4)
        valiable_header = ''
        valiable_header += Kwrb.encode_word @protocol
        valiable_header += Kwrb.encode @version
        valiable_header += Kwrb.encode((@user_flag << 7 + @password_flag << 6))
        valiable_header += Kwrb.encode_unsigned_short 0x0A
        header = fixed_header + valiable_header
        payload = ''
        payload += Kwrb.encode_word client_id
        payload += Kwrb.encode_word username
        payload += Kwrb.encode_word password
        @data = header + payload
      end
    end
    class Connack
      attr_reader :header
      def initialize
        @type = 0x02
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x02]
        valiable_header = [0x00]
        @header = fixed_header.concat valiable_header
      end

      def self.validate_code(code)
        case code
        when 0x00
          code
        when 0x01
          raise 'Connection Refused: unacceptable protocol version'
        when 0x02
          raise 'Connection Refused: identifer rejected'
        when 0x03
          raise 'Connection Refused: server unavailable'
        when 0x04
          raise 'Connection Refused: bad user name or password'
        when 0x05
          raise 'Connection Refused: not authorized'
        else
          raise "Connection Refused: #{code} is invalid"
        end
      end
    end
    class Publish
      attr_reader :header
      def initialize(topic, qos)
        @type = 0x03
        @dup = 0x00
        @qos = qos.to_i
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain]
        valiable_header = [0x00, topic.bytes.size, *topic.bytes, 0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Puback
      attr_reader :header
      def initialize
        @type = 0x04
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x02]
        valiable_header = [0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Pubrec
      attr_reader :header
      def initialize
        @type = 0x05
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x01]
        valiable_header = [0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Pubrel
      attr_reader :header
      def initialize
        @type = 0x06
        @dup = 0x00
        @qos = 0x01
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x01]
        valiable_header = [0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Pubcomp
      attr_reader :header
      def initialize
        @type = 0x07
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x01]
        valiable_header = [0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Subscribe
      attr_reader :header
      def initialize
        @type = 0x08
        @dup = 0x00
        @qos = 0x01
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain]
        valiable_header = [0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Suback
      attr_reader :header
      def initialize
        @type = 0x09
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain]
        valiable_header = [0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Unsubscribe
      attr_reader :header
      def initialize
        @type = 0x0A
        @dup = 0x00
        @qos = 0x01
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain]
        valiable_header = [0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Unsuback
      attr_reader :header
      def initialize
        @type = 0x0B
        @dup = 0x00
        @qos = 0x01
        @retain = 0x00
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x02]
        valiable_header = [0x00, @messeage_id]
        @header = fixed_header.concat valiable_header
      end
    end
    class Pingreq
      attr_reader :header
      def initialize
        @type = 0x0C
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        @header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x00]
      end
    end
    class Pingresp
      attr_reader :header
      def initialize
        @type = 0x0D
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        @header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x00]
      end
    end
    class Disconnect
      attr_reader :header
      def initialize
        @type = 0x0E
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        @header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x00]
      end
    end
  end
end
