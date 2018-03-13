
SELECT grape.network_insert('IPv4 all', '0.0.0.0/0');
SELECT grape.network_insert('IPv6 all', '::/0');

SELECT grape.network_insert('IPv4 localhost', '127.0.0.0/8');
SELECT grape.network_insert('IPv6 localhost', '::1/128');

SELECT grape.network_insert('PlatSoft LAN', '192.168.50.0/24');

