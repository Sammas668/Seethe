Stage 4.5g repeatable tactical benchmark

The runtime benchmark uses the current 64x64 tactical sandbox composition and
records session creation, validation and the subsystem performance snapshots.
Run:
  godot --headless --path . --script res://tests/performance/run_stage_4_5g_benchmark.gd

The benchmark output is a single STAGE_4_5G_BENCHMARK JSON line suitable for
comparison on the same reference machine. It deliberately does not invent
absolute pass/fail millisecond thresholds across unlike hardware.
