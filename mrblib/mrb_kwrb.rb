class Kwrb
  class Client < TCPSocket
    alias client_write write
    alias client_read  read
    alias client_close close

    def initialize; end

    def self.connect(host, port)
      super(host, port)
      new
    end

    def publish(topic, _payload)
      raise 'topic is invalid when publish message' if topic.nil?

      # FIXME: create packet for publish
      client_write('data')
    end

    def subscribe(topic, _payload)
      raise 'topic is invalid when subscribe message' if topic.nil?

      # FIXME: create packet for subscribe
      client_write('data')
    end

    def disconnect
      close_client
    end
  end

  class Packet
    def initialize(type, dup = 0, qos = 0, retain = 0)
      raise 'type is invalid' unless type >= 0 && type <= 15
      raise 'dup is invalid' unless dup == 0 || dup == 1
      raise 'qos is invalid' unless qos >= 0 && qos <= 3
      raise 'retain is invalid' unless retain == 0 || retain == 1

      @type = type
      @dup = dup
      @qos = qos
      @retain = retain
      @protocol = 'MQIsdp'
      @version = 3
      fixed_header = [@type, @dup, @qos, @retain]
      valiable_header = [0.chr, @protocol.size.chr, @protocol, @version.chr]
    end
  end
end
