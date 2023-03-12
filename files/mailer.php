<?php

	use PHPMailer\PHPMailer\PHPMailer;
	use PHPMailer\PHPMailer\SMTP;
	use PHPMailer\PHPMailer\Exception;

	require __DIR__ . "/../vendor/autoload.php";
	
	$mail = new PHPMailer();

	if(!file_exists(__DIR__ . "/login.json")){ exit(1); }
	
	$login_data = json_decode(file_get_contents(__DIR__ . "/login.json"), true);

	$mail->IsSMTP();
	$mail->CharSet = 'UTF-8';
	$mail->SMTPDebug = 0; 

	$mail->Host       = $login_data["hostname"];
	$mail->SMTPAuth   = true;
	$mail->Port       = 587;
	$mail->SMTPSecure = "tls";
	$mail->Username   = $login_data["admin_username"];
	$mail->Password   = $login_data["admin_password"];

	// Content
	$mail->setFrom($login_data["admin_username"] . "@" . $login_data["hostname"]);   
	$mail->addAddress($login_data["headless_email"]);

	$mail->isHTML(true);
	$mail->Subject = "DirectAdmin deployment was successful!";
	$mail->Body    = "DirectAdmin has been installed.<br>Hostname: " . $login_data["hostname"] . "<br>Admin username: " . $login_data["admin_username"] . "<br>Admin password: " . $login_data["admin_password"] . "<br>One-Time login URL: <a href=\"" . $login_data["login_url"] . "\">" . $login_data["login_url"] . "</a>";
	$mail->AltBody = "DirectAdmin has been installed.\\nHostname: " . $login_data["hostname"] . "\\nAdmin username: " . $login_data["admin_username"] . "\\nAdmin password: " . $login_data["admin_password"] . "\\nOne-Time login URL: " . $login_data["login_url"];

	$mail->send();

	exit(0);
?>