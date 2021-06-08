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

  def self.encode_message(message)
    [message].pack('a*')
  end

  def self.decode(val)
    val.unpack('C*')
  end

  def self.increment(val)
    val > 0xff ? 0x01 : val + 1
  end

  class Client
    MAXSIZE = 1024
    def initialize(socket)
      @message_id = 0x01
      @socket = socket
      @queue = Queue.new
    end

    def receive
      until @socket.closed?
        sockets = IO.select [@socket]
        sockets[0].each do |s|
          res = (begin
                   s.sysread MAXSIZE
                 rescue StandardError
                   nil
                 end)
          if res.nil?
            raise 'Failed: socket is already closed' if @socket.closed?

            pingreq
            next
          end

          @queue.enqueue res
        end
        break unless @queue.get.empty?
      end
    end

    def self.connect(host: '', username: nil, password: nil, qos: 0x00, clean_session: 0x01, port: 1883, client_id: 'test_client')
      @client_id = client_id.to_s
      if @client_id.empty? || @client_id.bytes.size > 23
        raise 'Failed: client id length is invalid'
      end
      raise 'Failed: host is invalid' if host.empty?

      @username = !username.nil? ? username : ''
      @password = !password.nil? ? password : ''
      @qos = qos
      @clean_session = clean_session

      socket = TCPSocket.open(host, port)
      connect_packet = Kwrb::Packet::Connect.new(@username, @password, @client_id, @qos, @clean_session)
      socket.syswrite connect_packet.data

      response = socket.sysread MAXSIZE
      raise 'Failed: receive invalid response' if response.nil?

      Kwrb::Packet::Connack.validate_packet(response)
      new socket
    end

    def publish(topic: nil, message: nil, qos: 0x00)
      raise 'Failed: topic is invalid when publish message' if topic.nil?
      raise 'Failed: message is invalid when publish message' if message.nil?
      if qos.negative? || qos >= 0x03
        raise 'Failed: qos is invalid when publish message'
      end

      publish_packet = Kwrb::Packet::Publish.new(topic, message, @message_id, qos)
      @socket.syswrite publish_packet.data
      return if qos.zero?

      receive
      response = @queue.dequeue

      case qos
      when 0x01
        Kwrb::Packet::Puback.validate_packet(response, @message_id)
      when 0x02
        Kwrb::Packet::Pubrec.validate_packet(response, @message_id)

        pubrel_packet = Kwrb::Packet::Pubrel.new(@message_id)
        @socket.syswrite pubrel_packet.data
        pubrel_response = @socket.read
        Kwrb::Packet::Pubcomp.validate_packet(pubrel_response, @message_id)
      else
        raise "Failed: qos level #{qos} is invalid"
      end
      Kwrb.increment(@message_id)
    end

    def subscribe(topic: nil, qos: 0x00)
      raise 'Failed: topic is invalid when subscribe message' if topic.nil?

      packet = Kwrb::Packet::Subscribe.new(topic, @message_id, qos)

      # FIXME: create payload for multiple topics
      @socket.syswrite packet.data
      receive

      response = @queue.dequeue
      Kwrb::Packet::Suback.validate_packet(response, @message_id, qos)

      puts "Sucscribe is Successful: subscribe '#{topic}'"
    end

    def read_message(topic: nil, qos: 0x00)
      raise 'Failed: topic is invalid when read message' if topic.nil?

      subscribe(topic: topic, qos: qos)
      loop do
        receive
        res = @queue.dequeue
        next if res.nil?

        packet = Kwrb::Packet::Puback.new(@message_id)
        @socket.syswrite packet.data if qos.positive?

        puts res
      end
    end

    def unsubscribe(topic)
      raise 'Failed: topic is invalid when unsubscribe message' if topic.nil?

      packet = Kwrb::Packet::Unsubscribe.new(topic, @message_id)

      # FIXME: create payload for multiple topics
      @socket.syswrite packet.data

      response = @socket.sysread MAXSIZE
      Kwrb::Packet::Unsuback.validate_packet(response, @message_id)

      puts 'Unsubscribe is Successful'
    end

    def pingreq
      packet = Kwrb::Packet::Pingreq.new
      @socket.syswrite packet.data
      response = @socket.sysread MAXSIZE
      Kwrb::Packet::Pingresp.validate_packet(response)
    end

    def disconnect
      packet = Kwrb::Packet::Disconnect.new
      @socket.syswrite packet.data
      @socket.close
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
      def initialize(username, password, client_id, qos, clean_session)
        @type = 0x01 << 4
        @protocol = 'MQTT'
        @version = 0x04
        @user_flag = !username.nil? ? 0x01 : 0x00
        @password_flag = !password.nil? ? 0x01 : 0x00
        @clean_session = clean_session
        variable_header = ''
        variable_header += Kwrb.encode_word @protocol
        variable_header += Kwrb.encode @version
        variable_header += Kwrb.encode((@user_flag << 7) + (@password_flag << 6) + (qos << 3) + (clean_session << 1))
        variable_header += Kwrb.encode_unsigned_short 0x0A
        payload = ''
        payload += Kwrb.encode_word client_id
        payload += Kwrb.encode_word username
        payload += Kwrb.encode_word password
        Kwrb::Packet.validate_packet_size(variable_header + payload)
        @remaining_length = Kwrb::Packet.generate_remaining_length(variable_header + payload)
        fixed_header = Kwrb.encode(@type) + Kwrb.encode(@remaining_length)
        header = fixed_header + variable_header
        @data = header + payload
      end
    end
    class Connack
      def self.validate_packet(binary)
        decoded = Kwrb.decode(binary)
        @type = 0x02 << 4
        @remaining_length = 0x02
        with_session = [@type, @remaining_length, 0x00]
        with_no_session = [@type, @remaining_length, 0x01]
        if (decoded[0..2] != with_session) && (decoded[0..2] != with_no_session)
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
      def initialize(topic, message, message_id, qos = 0x00, dup = 0x00, retain = 0x00)
        type = 0x03 << 4
        dup = dup.to_i << 3
        qos = qos.to_i << 1
        retain = retain.to_i
        topic = topic.to_s
        message = message.to_s
        message_id = message_id.to_i
        variable_header = ''
        variable_header += Kwrb.encode_word topic
        variable_header += Kwrb.encode_unsigned_short message_id
        payload = Kwrb.encode_message message
        Kwrb::Packet.validate_packet_size(variable_header + payload)
        remaining_length = Kwrb::Packet.generate_remaining_length(variable_header + payload)
        fixed_header = Kwrb.encode(type + dup + qos + retain) + Kwrb.encode(remaining_length)
        header = fixed_header + variable_header
        @data = header + payload
      end
    end
    class Puback
      attr_reader :data
      def initialize(message_id)
        type = 0x04 << 4
        message_id = message_id.to_i
        variable_header = ''
        variable_header += Kwrb.encode_unsigned_short message_id
        Kwrb::Packet.validate_packet_size(variable_header)
        remaining_length = Kwrb::Packet.generate_remaining_length(variable_header)
        fixed_header = Kwrb.encode(type) + Kwrb.encode(remaining_length)
        header = fixed_header + variable_header
        @data = header
      end

      def self.validate_packet(binary, message_id)
        decoded = Kwrb.decode(binary)
        type = 0x04 << 4
        remaining_length = 0x02
        fixed_data = [type, remaining_length, 0x00, message_id]
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
        fixed_data = [type, remaining_length, 0x00, message_id]
        if decoded != fixed_data
          raise 'Failed: packet is invalid when read Pubrec'
        end
      end
    end
    class Pubrel
      attr_reader :data
      def self.validate_packet(binary, message_id)
        decoded = Kwrb.decode(binary)
        type = 0x06 << 4
        remaining_length = 0x02
        fixed_data = [type, remaining_length, 0x00, message_id]
        if decoded != fixed_data
          raise 'Failed: packet is invalid when read Pubrec'
        end
      end
    end
    class Pubcomp
      def self.validate_packet(binary, message_id)
        decoded = Kwrb.decode(binary)
        type = 0x07 << 4
        remaining_length = 0x02
        fixed_data = [type, remaining_length, 0x00, message_id]
        if decoded != fixed_data
          raise 'Failed: packet is invalid when read Pubcomp'
        end
      end
    end
    class Subscribe
      attr_reader :data
      def initialize(topic, message_id, qos)
        type = 0x08 << 4
        dup = 0x00 << 3
        retain = 0x00
        message_id = message_id.to_i
        variable_header = ''
        variable_header += Kwrb.encode_unsigned_short message_id
        payload = ''
        payload += Kwrb.encode_word topic
        payload += Kwrb.encode qos
        Kwrb::Packet.validate_packet_size(variable_header + payload)
        remaining_length = Kwrb::Packet.generate_remaining_length(variable_header + payload)
        fixed_header = Kwrb.encode(type + dup + (qos << 1) + retain) + Kwrb.encode(remaining_length)
        @data = fixed_header + variable_header + payload
      end
    end
    class Suback
      def self.validate_packet(binary, message_id, qos)
        decoded = Kwrb.decode(binary)
        type = 0x09 << 4
        remaining_length = 0x03
        fixed_data = [type, remaining_length, 0x00, message_id, qos]
        if decoded != fixed_data
          raise 'Failed: packet is invalid when read Suback'
        end
      end
    end
    class Unsubscribe
      attr_reader :data
      def initialize(topic, message_id)
        type = 0x0A << 4
        qos = 0x01
        message_id = message_id.to_i
        variable_header = Kwrb.encode_unsigned_short message_id
        payload = ''
        payload += Kwrb.encode_word topic
        payload += Kwrb.encode_unsigned_short qos
        Kwrb::Packet.validate_packet_size(variable_header + payload)
        remaining_length = Kwrb::Packet.generate_remaining_length(variable_header + payload)
        fixed_header = Kwrb.encode(type + dup + (qos << 1) + retain) + Kwrb.encode(remaining_length)
        @data = fixed_header + variable_header + payload
      end
    end
    class Unsuback
      def self.validate_packet(binary, message_id)
        decoded = Kwrb.decode(binary)
        type = 0x0B
        remaining_length = 0x02
        fixed_data = [type, remaining_length, 0x00, message_id]
        if decoded != fixed_data
          raise 'Failed: packet is invalid when read Unsuback'
        end
      end
    end
    class Pingreq
      attr_reader :data
      def initialize
        type = 0x0C << 4
        dup = 0x00  << 3
        qos = 0x00 << 1
        retain = 0x00
        remaining_length = 0x00
        fixed_header = Kwrb.encode(type + dup + qos + retain) + Kwrb.encode(remaining_length)
        @data = fixed_header
      end
    end
    class Pingresp
      def self.validate_packet(binary)
        decoded = Kwrb.decode(binary)
        type = 0x0D << 4
        remaining_length = 0x00
        fixed_data = [type, remaining_length]
        if decoded != fixed_data
          raise 'Failed: packet is invalid when read Pingresp'
        end
      end
    end
    class Disconnect
      attr_reader :data
      def initialize
        type = 0x0E << 4
        remaining_length = 0x00
        fixed_header = Kwrb.encode(type) + Kwrb.encode(remaining_length)
        @data = fixed_header
      end
    end
  end
end
