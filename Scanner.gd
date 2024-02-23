extends Node
class_name PortScanner
## @experimental Node to search for open ports.

signal scan_finished(result: PackedInt32Array)
signal scan_port_found(port: int)
var scan_active := false
var waiter: Thread


func start_scan(addr: String, from: int, to: int, num_threads: int, timeout_physics_frames := 20) -> void:
	if scan_active:
		push_error('Scan in progress')
		return
	scan_active = true

	var scan_range := to - from
	var step := scan_range / num_threads
	var remainder := scan_range % num_threads
	print_verbose(from, ' - ', to, ' x ', num_threads)
	print_verbose('step: ', step)
	print_verbose('remainder: ', remainder)

	var results := PackedInt32Array()
	var results_mutex := Mutex.new()
	var threads: Array[Thread] = []

	for i in num_threads:
		var _from := from + step * i
		var _to := _from + step
		print_verbose(i, ': ', _from, ' - ', _to)
		threads.append(_thread_start(_from, _to, addr, timeout_physics_frames, results, results_mutex))

	if remainder:
		var _from := to - remainder
		var _to := to
		print_verbose('x: ', _from, ' - ', _to)
		threads.append(_thread_start(_from, _to, addr, timeout_physics_frames, results, results_mutex))

	waiter = Thread.new()
	waiter.start(
		func() -> void:
			for thread in threads:
				thread.wait_to_finish()
			scan_finished.emit.call_deferred(results)
			scan_active = false

			print_verbose('Waiter done')
	)
	print_verbose('Started Waiter')


func timeout_sec(seconds: float) -> int:
	var physics_tick_length_sec := 1.0 / Engine.physics_ticks_per_second
	return seconds / physics_tick_length_sec

func runtime_sec_approx(start: int, end: int, timeout_physics_frames: int, thread_amount: int) -> float:
	var port_amount := end - start
	var physics_tick_length_sec := 1.0 / Engine.physics_ticks_per_second
	return (port_amount * timeout_physics_frames * physics_tick_length_sec) / thread_amount

func _scan(from: int, to: int, addr: String, timeout_physics_frames: int, output: PackedInt32Array, results_mutex: Mutex) -> void:
	print_verbose('> ', OS.get_thread_caller_id())

	for port in range(from, to):
		print_verbose('Checking ', port)
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(addr, port)
		if err:
			push_error('Failed to create client to scan on port ', port, ':', error_string(err))
			continue

		var semaphore := Semaphore.new()
		var test := func(s: Semaphore) -> void: s.post()

		for i in timeout_physics_frames:
			get_tree().physics_frame.connect.call_deferred(
				test.bind(semaphore),
				CONNECT_ONE_SHOT
			)
			semaphore.wait()
			peer.poll()
			var status := peer.get_connection_status()

			if status == MultiplayerPeer.CONNECTION_CONNECTING:
				continue
			else:

				if status == MultiplayerPeer.CONNECTION_CONNECTED:
					print_verbose('PORT OPEN: ', port)
					peer.close()
					scan_port_found.emit.call_deferred(port)

					results_mutex.lock()
					output.append(port)
					results_mutex.unlock()
					break
				elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
					print_verbose('Disconnected? ', port)
					break
				else:
					push_error('?')

	print_verbose('< ', OS.get_thread_caller_id())


func _thread_start(from: int, to: int, addr: String, timeout_physics_frames: int, output: PackedInt32Array, results_mutex: Mutex) -> Thread:
	var t := Thread.new()
	t.start(_scan.bind(from, to, addr, timeout_physics_frames, output, results_mutex))
	return t
