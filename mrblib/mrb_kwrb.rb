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
      @message_id = 0x01
    end

    def self.connect(host, username = nil, password = nil, port = 1883, client_id = 'test_client')
      @client_id = client_id.to_s
      if @client_id.empty? || @client_id.bytes.size > 23
        raise 'Failed: client id length is invalid'
      end

      @username = !username.nil? ? username : ''
      @password = !password.nil? ? password : ''

      @socket = TCPSocket.open(host, port)
      connect_packet = Kwrb::Packet::Connect.new(@username, @password, @client_id)
      @socket.write connect_packet.data

      response = @socket.read
      raise 'Failed: receive invalid response' if response.nil?

      Kwrb::Packet::Connack.validate_packet(response)
      puts 'Connect is Successful'
      new
    end

    def publish(topic, message, qos = 0x00)
      raise 'Failed: topic is invalid when publish message' if topic.nil?
      raise 'Failed: message is invalid when publish message' if message.nil?
      if qos.negative? || qos >= 0x03
        raise 'Failed: qos is invalid when publish message'
      end

      publish_packet = Kwrb::Packet::Publish.new(topic, message, @message_id, qos)
      @socket.write publish_packet.data
      response = @socket.read
      case qos
      when 0x00
        return
      when 0x01
        Kwrb::Packet::Puback.validate_packet(response, @message_id)
      when 0x02
        Kwrb::Packet::Pubrec.validate_packet(response, @message_id)

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
      @message_id += 1
      puts message
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
    def self.generate_remaining_length(val)
      size = val.bytes.size
      digit = 0
      loop do
        digit = size % 0x80
        size = size.div(0x80)
        digit |= 0x80 if size > 0
        break if size <= 0
      end
      digit
    end

    def self.validate_packet_size(val)
      size = val.bytes.size
      raise 'Failed: byte size is invalid' if size > 268_435_455
    end
    class Connect
      attr_reader :data
      def initialize(username, password, client_id)
        @type = 0x01 << 4
        @protocol = 'MQIsdp'
        @version = 0x03
        @user_flag = !username.nil? ? 1 : 0
        @password_flag = !password.nil? ? 1 : 0
        valiable_header = ''
        valiable_header += Kwrb.encode_word @protocol
        valiable_header += Kwrb.encode @version
        valiable_header += Kwrb.encode((@user_flag << 7) + (@password_flag << 6))
        valiable_header += Kwrb.encode_unsigned_short 0x0A
        payload = ''
        payload += Kwrb.encode_word client_id
        payload += Kwrb.encode_word username
        payload += Kwrb.encode_word password
        Kwrb::Packet.validate_packet_size(payload)
        @remaining_length = Kwrb::Packet.generate_remaining_length(valiable_header + payload)
        fixed_header = Kwrb.encode(@type) + Kwrb.encode(@remaining_length)
        header = fixed_header + valiable_header
        @data = header + payload
      end
    end
    class Connack
      def self.validate_packet(binary)
        decoded = Kwrb.decode(binary)
        @type = 0x01 << 5
        @remaining_length = 0x02
        topic_name = 0x00
        fixed_data = [@type, @remaining_length, topic_name]
        if decoded[0..2] != fixed_data
          raise 'Failed: packet is invalid when read Connack'
        end

        code = decoded.last
        case code
        when 0x00
          return
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
      attr_reader :data
      def initialize(topic, message, message_id, qos = 1, dup = 0, retain = 0)
        type = 0x03 << 4
        topic = topic.to_s
        message = message.to_s
        message_id = message_id.to_i
        dup = dup.to_i << 3
        qos = qos.to_i << 1
        retain = retain.to_i
        valiable_header = ''
        valiable_header += Kwrb.encode_word topic
        valiable_header += Kwrb.encode_unsigned_short message_id
        payload = ''
        payload += Kwrb.encode_word message
        Kwrb::Packet.validate_packet_size(payload)
        remaining_length = Kwrb::Packet.generate_remaining_length(valiable_header + payload)
        fixed_header = Kwrb.encode(type + dup + qos + retain) + Kwrb.encode(remaining_length)
        header = fixed_header + valiable_header
        @data = header + payload
      end
    end
    class Puback
      def self.validate_packet(binary, message_id)
        decoded = Kwrb.decode(binary)
        type = 0x04 << 4
        remaining_length = 0x02
        fixed_data = [type, remaining_length, 0x00, message_id.bytes.length]
        if decoded != fixed_data
          raise 'Failed: packet is invalid when read Puback'
        end
      end
    end
    class Pubrec
      def self.validate_packet(binary, message_id)
        decoded = Kwrb.decode(binary)
        type = 0x05 << 4
        remaining_length = 0x02
        fixed_data = [type, remaining_length, 0x00, message_id.bytes.length]
        if decoded != fixed_data
          raise 'Failed: packet is invalid when read Pubrec'
        end
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
        valiable_header = [0x00, @message_id]
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
        valiable_header = [0x00, @message_id]
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
        valiable_header = [0x00, @message_id]
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
        valiable_header = [0x00, @message_id]
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
        valiable_header = [0x00, @message_id]
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
        valiable_header = [0x00, @message_id]
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
