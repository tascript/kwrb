class Kwrb
  class Client
    def initialize
      @messeage_id = 0x01
    end

    def self.connect(host, port = 1883, id = 'test')
      @client_id = id.to_s
      raise 'type is invalid' if @client_id.empty? || @client_id.size > 23

      # connect with host and send payload
      @socket = TCPSocket.open(host, port)
      connect_packet = Kwrb::Packet::Connect.new
      payload = connect_packet.header.concat @client_id.bytes
      @socket.write payload.pack('C*')

      # validate connack response
      res = @socket.read
      res_header = res.unpack('C*')[0]
      res_code = res.unpack('C*')[1]
      connack_packet = Kwrb::Packet::Connack.new
      if res_header != connack_packet.header
        raise 'header is invalid when read connack'
      end
      raise 'response from blocker is invalid' unless res_code.zero?

      Kwrb::Packet::Connack.validate_code(res_code)

      new
    end

    def publish(topic, messgae)
      if topic.nil? || messgae.nil?
        raise 'argument is invalid when publish message'
      end

      header = Kwrb::Packet::Publish.new(topic)
      payload = header.concat messgae
      @socket.write payload.pack('C*')
      @messeage_id += 1
    end

    def subscribe(topic)
      raise 'topic is invalid when subscribe message' if topic.nil?

      packet = Kwrb::Packet::Subscribe.new
      header = packet.header

      # FIXME: create payload for multiple topics
      payload = [*header, topic.bytes.size, *topic.bytes, 0x01]
      @socket.write payload.pack('C*')
      @messeage_id += 1
    end

    def disconnect
      packet = Kwrb::Packet::Disconnect.new
      header = packet.header
      @socket.write header.pack('C*')
      @socket.close
    end
  end

  class Packet
    class Connect
      attr_reader :header
      def initialize
        @type = 0x01
        @dup = 0x00
        @qos = 0x00
        @retain = 0x00
        @protocol = 'MQIsdp'
        @version = 0x03
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain]
        valiable_header = [0x00, @protocol.bytes.size, *@protocol.bytes, @version, 0x00, 0x00, 0x0A]
        @header = fixed_header.concat valiable_header
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
      def initialize(topic)
        @type = 0x03
        @dup = 0x00
        @qos = 0x01
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
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x02]
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
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x02]
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
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain, 0x02]
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
