function check (timestamp) {
	setTimeout (function () {
		var request = new XMLHttpRequest;
		request.onreadystatechange = function () {
			if (request.readyState === 4 && request.status === 200)
				if (request.responseText !== timestamp) location.reload (); else check (timestamp);
		};
		request.open ("GET", "date");
		request.send ();
	}, 2500);
}

function load (page) {
	if ("replaceState" in history) history.replaceState (null, "", page.href); else return true;
	var request = new XMLHttpRequest;
	request.onreadystatechange = function () {
		if (request.readyState === 4 && request.status === 200)
			page.parentNode.parentNode.parentNode.parentNode.innerHTML = request.responseText;
	};
	request.open ("GET", page.href + ".log");
	request.send ();
	return false;
}

function update (timers) {
	for (var i = 0; i !== timers.length; i++) {
		var timer = timers[i]; if (timer === null) break; text = timer.innerHTML;
		var duration = parseInt (text, 10) * 3600 + parseInt (text.substr (3), 10) * 60 + parseInt (text.substr (6), 10) + 1;
		timer.innerHTML = [("0" + Math.floor (duration / 3600)).slice (-2), ("0" + Math.floor (duration / 60) % 60).slice (-2), ("0" + duration % 60).slice (-2)].join (":");
	}
}

if ("getElementsByClassName" in document) setInterval (update, 1000, document.getElementsByClassName ("timer"));
