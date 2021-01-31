class Kwrb
  class Client
    def self.connect(host, port = 1883, id = 'test')
      @client_id = id.to_s
      raise 'type is invalid' if @client_id.empty? || @client_id.size > 23

      # connect with host and send payload
      @socket = TCPSocket.open(host, port)
      base_packet = Kwrb::Packet::Connect.new
      payload = base_packet.header.concat @client_id.bytes
      @socket.write payload.pack('C*')

      # validate connack response
      res = @socket.read
      res_header = res.unpack('C*')[0]
      res_code = res.unpack('C*')[1]
      header = Kwrb::Packet::Connack.new
      raise 'header is invalid when read connack' if res_header != header
      raise 'response from blocker is invalid' unless res_code.zero?

      new
    end

    def publish(topic, _payload)
      raise 'topic is invalid when publish message' if topic.nil?

      # FIXME: create packet for publish
      client_write 'data'
    end

    def subscribe(topic, _payload)
      raise 'topic is invalid when subscribe message' if topic.nil?

      # FIXME: create packet for subscribe
      client_write 'data'
    end

    def disconnect
      close_client
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
        fixed_header = [(0x01 << 5), 0x00]
        valiable_header = [0x00]
        @header = fixed_header.concat valiable_header
      end

      def self.validate_code(code)
        case code
        when 0x00
          true
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
  end
end
