<?php

function f($method, $path, $body, $username, $password)
{
	$req_url = $path;
	$ch = curl_init($req_url); 
	if ($method == 'POST')
	{
		$data = json_encode($body);
		curl_setopt($ch, CURLOPT_POST, true);
		curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
	}
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
	curl_setopt($ch, CURLOPT_HEADER, 1);
	curl_setopt($ch, CURLOPT_HTTPHEADER, 
		array("Content-type: application/json", 
		"Accept: application/json",
		"Authorization: Basic " . base64_encode("$username:$password")
		));

	$data = curl_exec($ch);
	$info = curl_getinfo($ch);
	curl_close($ch);

	$header = substr($data, 0, $info['header_size']);
	$body = substr($data, $info['header_size']);
	print_r(array('header' => $header, 'body' => $body));
}

f(
	'POST', 
	'http://localhost:3000/grape/list', 
	array('schema' => 'grape', 'tablename' => 'setting'),
	'USERNAME', 'PASSWORD'
);

?>
