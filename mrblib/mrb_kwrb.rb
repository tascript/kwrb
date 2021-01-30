class Kwrb
  class Client < TCPSocket
    alias client_write write
    alias client_read  read
    alias client_close close
    def initialize(*arg); end

    def self.connect(host, port = 1883, id = 'test')
      @client_id = id.to_s
      raise 'type is invalid' if @client_id.empty? || @client_id.size > 23

      @socket = TCPSocket.open(host, port)
      base_packet = Kwrb::Packet::Connect.new(1)
      payload = base_packet.header.concat @client_id.bytes
      @socket.write payload.pack('C*')
      new
    end

    def connack
      res = @socket
      raise 'response is invalid when read connack' if res.nil?

      res_header = res.unpack('C*')[0..2]
      res_code = res.unpack('C*')[3]
      header = Kwrb::Packet::Connack.new
      raise 'header is invalid when read connack' unless res_header == header

      res_code
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
      def initialize(type, dup = 0, qos = 0, retain = 0)
        raise 'type is invalid' unless type >= 0 && type <= 15
        raise 'dup is invalid' unless dup.zero? || dup == 1
        raise 'qos is invalid' unless qos >= 0 && qos <= 3
        raise 'retain is invalid' unless retain.zero? || retain == 1

        @type = type
        @dup = dup
        @qos = qos
        @retain = retain
        @protocol = 'MQIsdp'
        @version = 3
        fixed_header = [(@type << 4) + (@dup << 3) + (@qos << 1) + @retain]
        valiable_header = [0x00, @protocol.bytes.size, *@protocol.bytes, @version, 0x00, 0x00, 0xA0]
        @header = fixed_header.concat valiable_header
      end
    end
    class Connack
      attr_reader :header
      def initialize
        fixed_header = [(0x01 << 5), 0]
        valiable_header = [0]
        @header = fixed_header.concat valiable_header
      end
    end
  end
end
