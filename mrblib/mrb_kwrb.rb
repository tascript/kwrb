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

    def publish(topic, payload, retain = 0); end

    def subscribe(topic, _payload, _retain = 0)
      raise 'topic is invalid' if topic.nil?
    end

    def disconnect
      close_client
    end
  end

  class Packet
    def initialize; end
  end
end
