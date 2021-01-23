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

    def publish(topic, _payload, _retain = 0)
      raise 'topic is invalid when publish message' if topic.nil?

      # FIXME: create packet for publish
      client_write('data')
    end

    def subscribe(topic, _payload, _retain = 0)
      raise 'topic is invalid when subscribe message' if topic.nil?

      # FIXME: create packet for subscribe
      client_write('data')
    end

    def disconnect
      close_client
    end
  end

  class Packet
    def initialize; end
  end
end
