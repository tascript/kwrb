class Kwrb < TCPSocket

  def initialize(topic)
    @topic = topic.to_s
  end

  def connect
  end

  def publish
  end

  def subscribe
  end

  def close
  end
end
