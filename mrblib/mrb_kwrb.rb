class Kwrb
  class Client < TCPSocket
    alias client_write write
    alias client_read  read
    alias client_close close

    def initialize(topic)
      @topic = topic.to_s
    end

    def connect(host, port)
      super(host, port)
    end

    def publish(payload, retain = 0); end

    def subscribe; end

    def disconnect
      close_client
    end
  end

  class Packet
    def initialize; end
  end
end
