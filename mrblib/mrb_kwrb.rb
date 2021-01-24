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

    def publish(topic, _payload,)
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
    def initialize(type, dup, qos, retain)
      unless type.instance_of?(Integer) &&
             dup.instance_of?(Integer) &&
             qos.instance_of?(Integer) &&
             retain.instance_of?(Integer)
        raise 'argument type is invalid'
      end

      @type = type
      @dup = dup
      @qos = qos
      @retain = retain
      header = (@type << 4) + (@dup << 3) + (@qos << 1) + @retain 
    end
  end
end
