class Kwrb < TCPSocket
  class Client
    def initialize(topic)
      @topic = topic.to_s
    end

    def connect; end

    def publish(payload, retain = 0); end

    def subscribe; end

    def disconnect; end
  end

  class Packet
    def initialize; end
  end
end
