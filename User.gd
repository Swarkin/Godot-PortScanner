extends Node

@onready var example_server := $Server
@onready var scanner := $Scanner as PortScanner

func _ready() -> void:
	example_server.start()

	var start := 9000
	var end := 10000
	var timeout := 5.0
	var threads := 100

	print('This will take approximately ', scanner.runtime_sec_approx(start, end, scanner.timeout_sec(timeout), threads), 's')

	# Prefer inputting IP instead of domain
	scanner.start_scan('127.0.0.1', start, end, threads, scanner.timeout_sec(5.0))
	print('All ports found:', await scanner.scan_finished as PackedInt32Array)


func _on_scanner_port_found(port: int) -> void:
	print('Port found: ', port)
