plan bolt_haproxy::provision(
  TargetSpec $targets,
  TargetSpec $backend_servers,
) {
  apply_prep([$targets, $backend_servers])

  $backends = get_targets($backend_servers)
  $server_names = $backends.map |$t| { $t.host }
  $ipaddresses = $backends.map |$t| { $t.facts['networking']['ip'] }
  out::message("Load balancing across ${server_names} (${ipaddresses})")

  $apply_results = apply($targets) {
    # Sometimes need to `yum reinstall selinux-policy` for this to work
    selinux::boolean { 'haproxy_connect_any': }
    -> class { 'haproxy':
      global_options   => {},
      defaults_options => {
        'timeout' => [
          'client  60s',
          'server  60s',
          'connect 60s',
          'tunnel 300s',
        ],
      },
      merge_options    => false,
    }

    Haproxy::Listen {
      collect_exported => false,
    }

    # Sets up a status UI on port 8080
    haproxy::listen { 'stats':
      ipaddress => '*',
      ports     => '8080',
      mode      => 'http',
      options   => {
        'stats' => [
          'enable',
          'uri /',
          'hide-version',
        ],
      },
    }

    Haproxy::Frontend {
      ipaddress => '*',
      mode      => 'tcp',
    }

    $services = {'app' => ['80', '443'], 'kubeapi' => '6443', 'webhook' => '8000', 'admin' => '8800'}
    $services.each |String $service, Variant[String, Array[String]] $port| {
      haproxy::frontend { $service:
        ports   => $port,
        options => {
          'default_backend' => $service,
        }
      }

      # An array of ports are treated as the same service, so only healthcheck one.
      $extra_options = $port ? {
        Array[String] => { 'tcp-check' => "connect port ${$port[0]}" },
        default       => {},
      }

      haproxy::backend { $service:
        options => {
          'balance' => 'roundrobin',
          'option'  => ['tcp-check'],
        } + $extra_options
      }

      # An array of ports are load balanced to the same backends, but each port should map to the
      # matching port on the backend. This is most easily accomplished by omitting them.
      $member_port = $port ? {
        Array[String] => undef,
        default       => $port,
      }

      haproxy::balancermember { $service:
        listening_service => $service,
        ports             => $member_port,
        server_names      => $server_names,
        ipaddresses       => $ipaddresses,
        options           => 'check',
      }
    }
  }

  $apply_results.each |$result| {
    $result.report['logs'].each |$log| {
      out::message("${log['level'].upcase}: ${log['message']}")
    }
  }
}
