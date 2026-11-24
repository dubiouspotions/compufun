// Speaks a line live in the browser: Chimera (chimera_voice.wasm) renders it in a Web Worker, chunk
// by chunk, and the page plays each chunk as it arrives. Godot loads this with JavaScriptBridge.
(() => {
	const RATE = 22050;

	// Runs in the worker: owns the wasm, renders one line at a time, drops a line that a newer
	// say or stop replaced.
	const workerMain = () => {
		// About 90 ms of audio: small enough to start at once, big enough to stay ahead.
		const CHUNK = 2048;
		let w = null;
		let loaded = null;
		let current = 0;
		const put = (bytes) => {
			const p = w.say_alloc(bytes.length);
			new Uint8Array(w.memory.buffer, p, bytes.length).set(bytes);
			return p;
		};
		const pause = () => new Promise((resolve) => setTimeout(resolve, 0));
		onmessage = async (e) => {
			const m = e.data;
			try {
				if (m.kind === "init") {
					loaded = (async () => {
						w = (await WebAssembly.instantiate(m.wasm, {})).instance.exports;
						const dict = new Uint8Array(await new Response(new Blob([m.dict]).stream().pipeThrough(new DecompressionStream("gzip"))).arrayBuffer());
						w.say_load_dict(put(dict), dict.length);
					})();
					await loaded;
					postMessage({ kind: "ready" });
				} else if (m.kind === "stop") {
					current = m.id;
				} else if (m.kind === "say") {
					current = m.id;
					await loaded; // the first say arrives right behind init
					// The parts of a line, rendered one after another into the same stream of chunks.
					for (const part of m.parts) {
						if (current !== m.id) return;
						const type = new TextEncoder().encode(part.voiceType || "");
						w.say_voice_type(type.length ? put(type) : 0, type.length);
						const text = new TextEncoder().encode(part.text);
						const total = w.say_start(put(text), text.length, m.body, m.rate, part.speed, part.pitch, part.accent);
						if (total === 0) throw new Error("say_start rendered nothing for: " + part.text);
						while (current === m.id) {
							const n = w.say_render(CHUNK);
							if (n === 0) break;
							const chunk = new Float32Array(w.memory.buffer, w.say_buffer(), n).slice();
							postMessage({ kind: "chunk", id: m.id, samples: chunk }, [chunk.buffer]);
							await pause();
						}
					}
				}
			} catch (err) {
				postMessage({ kind: "error", message: String(err && err.stack || err) });
			}
		};
	};

	let worker = null;
	let ctx = null;
	let gain = null;
	let analyser = null;
	let heard = null;
	let id = 0;
	let next = 0;
	let sources = [];
	const api = {
		ready: false,
		// Called with a message when anything fails; Godot sets it to surface the error.
		onerror: (message) => console.error("live voice:", message),

		// wasm, dict: base64 of chimera_voice.wasm and cmudict.txt.gz.
		init(wasm, dict) {
			const bytes = (b64) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
			const url = URL.createObjectURL(new Blob(["(" + workerMain.toString() + ")()"], { type: "text/javascript" }));
			worker = new Worker(url);
			worker.onerror = (e) => api.onerror(e.message || String(e));
			worker.onmessage = (e) => {
				const m = e.data;
				if (m.kind === "ready") api.ready = true;
				else if (m.kind === "error") api.onerror(m.message);
				else if (m.kind === "chunk" && m.id === id) api._play(m.samples);
			};
			const wasmBytes = bytes(wasm);
			const dictBytes = bytes(dict);
			worker.postMessage({ kind: "init", wasm: wasmBytes.buffer, dict: dictBytes.buffer }, [wasmBytes.buffer, dictBytes.buffer]);
		},

		// Says one line. partsJson: a JSON array of its parts, each { text, speed, pitch, accent,
		// voiceType }, said one after another without a pause; speed and pitch are multipliers,
		// accent < 0 is the default, voiceType is a voice type's text form ("" says it plainly).
		// body: 0 male, 1 female, 2 child. volume is linear.
		sayParts(partsJson, body, volume) {
			api.stop();
			if (!ctx) {
				ctx = new AudioContext();
				gain = ctx.createGain();
				gain.connect(ctx.destination);
				analyser = ctx.createAnalyser();
				analyser.fftSize = 512;
				analyser.connect(gain);
				heard = new Float32Array(analyser.fftSize);
			}
			if (ctx.state === "suspended") ctx.resume();
			gain.gain.value = volume;
			id += 1;
			next = 0;
			worker.postMessage({ kind: "say", id, parts: JSON.parse(partsJson), body, rate: RATE });
		},

		stop() {
			id += 1;
			if (worker) worker.postMessage({ kind: "stop", id });
			for (const s of sources) s.stop();
			sources = [];
		},

		// The peak of the last 512 samples that played, linear, before the volume.
		level() {
			if (!analyser) return 0;
			analyser.getFloatTimeDomainData(heard);
			let peak = 0;
			for (const v of heard) peak = Math.max(peak, Math.abs(v));
			return peak;
		},

		_play(samples) {
			const buffer = ctx.createBuffer(1, samples.length, RATE);
			buffer.copyToChannel(samples, 0);
			const source = ctx.createBufferSource();
			source.buffer = buffer;
			source.connect(analyser);
			// A little lead on the first chunk, so the next ones arrive before it ends.
			next = Math.max(next, ctx.currentTime + 0.05);
			source.start(next);
			next += buffer.duration;
			source.onended = () => { sources = sources.filter((x) => x !== source); };
			sources.push(source);
		},
	};
	window.humanerrorVoice = api;
})();
