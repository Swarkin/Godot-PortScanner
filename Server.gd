extends Node

var peer := ENetMultiplayerPeer.new()


func start() -> void:
	var err := peer.create_server(9090)
	if err:
		print(error_string(err))
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(id: int) -> void:
		print('server: ', id, ' connected')
	)
	multiplayer.peer_disconnected.connect(func(id: int) -> void:
		print('server: ', id, ' disconnected')
	)
