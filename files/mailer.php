<?php
	
	if(!file_exists(__DIR__ . "/login.json")){ exit(1); }
	
	$login_data = json_decode(file_get_contents(__DIR__ . "/login.json"), true);

	$message = "DirectAdmin has been installed.\\nHostname: " . $login_data["hostname"] . "\\nAdmin username: " . $login_data["admin_username"] . "\\nAdmin password: " . $login_data["admin_password"] . "\\nOne-Time login URL: " . $login_data["login_url"];
	$headers = array(
		'From' => $login_data["admin_username"] . "@" . $login_data["hostname"],
		'Reply-To' => $login_data["admin_username"] . "@" . $login_data["hostname"],
	);

	mail($login_data["headless_email"], "Cloud-Init DirectAdmin deployment created by realcryptonight was successful!", $message, $headers);
	
	exit(0);
?>