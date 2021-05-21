plan bolt_haproxy::provision(
  TargetSpec $targets,
  String $artifactory_ip,
  String $artifactory_path,
  String $single_path,
) {

  $targets.apply_prep

  # Apply code
  $apply_results = apply($targets) {

    include haproxy

    selboolean { 'haproxy_connect_any':
      persistent => true,
      value      => 'on',
    }

    haproxy::frontend { 'http':
      bind    => {"${facts['ipaddress']}:80" => []},
      mode    => 'http',
      options => {
        'reqadd'      => 'X-Forwarded-Proto:\ http',
        'acl'         => "ACL_artifactory hdr(host) -i ${facts['fqdn']}",
        'use_backend' => 'artifactory_http if ACL_artifactory',
      },
    }

    haproxy::backend { 'artifactory_http':
      mode    => 'http',
      options => [
        {'server' => "artifactory ${artifactory_ip}:443 check ssl verify none"},
        {'reqrep' => "^([^\\ :]*)\\ ${single_path}[/]?(.*) \\1\\ ${artifactory_path}\\2"},
      ],
    }

    haproxy::backend { 'default':
      mode    => 'http',
      options => {'server' => 'localhost 127.0.0.1:80'},
    }

  }

  # Print log messages
  $apply_results.each |$result| {
    $result.report['logs'].each |$log| {
      out::message("${log['level'].upcase}: ${log['message']}")
    }
  }

}
