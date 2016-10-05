# A simple openflow controller for benchmarking.
class Cbench < Trema::Controller
  def start(_args)
    logger.info 'Cbench started.'
  end

  def packet_in(datapath_id, message)
    send_flow_mod_add(
      datapath_id,
      match: Match.new(in_port:message.in_port),
      buffer_id: message.buffer_id,
      actions: SendOutPort.new(message.in_port + 1)
    )
  end
end
