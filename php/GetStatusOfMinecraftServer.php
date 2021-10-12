<?php
    function getServerData($url, $port) {
        if($sock = @stream_socket_client("tcp://{$url}:{$port}", $errno, $errstr, 1)) {
            fwrite($sock, "\xfe");
            $h = fread($sock, 2048);
            $h = str_replace("\x00", '', $h);
            $h = substr($h, 2);
            $data = explode("\xa7", $h);
            unset($h);
            fclose($sock);
            if (sizeof($data) == 3) {
                return array(
                    'url' => $url,
                    'port' => $port,
                    'motd' => $data[0], 
                    'onlinePlayers' => (int) $data[1], 
                    'maxPlayers' => (int) $data[2]
                );
            }
        }
        return false;
    }

    // ------------------------------------------------------------

    $data = getServerData('<url>', 25565);
    if($data !== false) {
        echo "Data of Server: {$data['url']}:{$data['port']}\n";
        echo "Motd: {$data['motd']}\n";
        echo "There are {$data['onlinePlayers']} of {$data['maxPlayers']} players online";
    } else {
        echo "The server is offline";
    }
