<?php

class GrapeClient
{
	private $sessionid = null;
	private $url;

	function __construct ($url)
	{
		$this->url = $url;
	}

	function login($username, $password)
	{
		$this->post("/grape/login", array("username" => $username, "password" => $password));
	}

	function logout()
	{
		$this->post("/grape/logout");
	}

	function get($path, $params)
	{
		return $this->request('GET', $path, $body);
	}

	function post($path, $body=array())
	{
		return $this->request('POST', $path, $body);
	}

	function request($method, $path, $body=array())
	{
		$req_url = $this->url . $path;
		$ch = curl_init($req_url); 
		if ($method == 'POST')
		{
			$data = json_encode($body);
			curl_setopt($ch, CURLOPT_POST, true);
			curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
		}
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_HEADER, 1);
		curl_setopt($ch, CURLOPT_HTTPHEADER, array("Content-type: application/json", "Accept: application/json"));

		$data = curl_exec($ch);
		$info = curl_getinfo($ch);
		curl_close($ch);

		$header = substr($data, 0, $info['header_size']);
		$body = substr($data, $info['header_size']);
		print_r(array('header' => $header, 'body' => $body));
		return array('header' => $header, 'body' => $body);
	}

}

$gc = new GrapeClient("http://localhost:3003");
$gc->login('HansL', 'hans');

$gc->post("/grape/list_query", array());

$gc->logout();

?>
