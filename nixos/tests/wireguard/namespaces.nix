let
  listenPort = 12345;
  socketNamespace = "foo";
  interfaceNamespace = "bar";
  node = {
    networking.wireguard.interfaces.wg0 = {
      listenPort = listenPort;
      ips = [ "10.10.10.1/24" ];
      privateKeyFile = "/etc/wireguard/private";
      generatePrivateKeyFile = true;
    };
  };

in

import ../make-test.nix ({ pkgs, ...} : {
  name = "wireguard-with-namespaces";
  meta = with pkgs.stdenv.lib.maintainers; {
    maintainers = [ asymmetric ];
  };

  nodes = {
    # interface should be created in the socketNamespace
    # and not moved from there
    peer0 = pkgs.lib.attrsets.recursiveUpdate node {
      networking.wireguard.interfaces.wg0 = {
        preSetup = ''
          ip netns add ${socketNamespace}
        '';
        inherit socketNamespace;
      };
    };
    # interface should be created in the init namespace
    # and moved to the interfaceNamespace
    peer1 = pkgs.lib.attrsets.recursiveUpdate node {
      networking.wireguard.interfaces.wg0 = {
        preSetup = ''
          ip netns add ${interfaceNamespace}
        '';
        inherit interfaceNamespace;
      };
    };
    # interface should be created in the socketNamespace
    # and moved to the interfaceNamespace
    peer2 = pkgs.lib.attrsets.recursiveUpdate node {
      networking.wireguard.interfaces.wg0 = {
        preSetup = ''
          ip netns add ${socketNamespace}
          ip netns add ${interfaceNamespace}
        '';
        inherit socketNamespace interfaceNamespace;
      };
    };
    # interface should be created in the socketNamespace
    # and moved to the init namespace
    peer3 = pkgs.lib.attrsets.recursiveUpdate node {
      networking.wireguard.interfaces.wg0 = {
        preSetup = ''
          ip netns add ${socketNamespace}
        '';
        inherit socketNamespace;
        interfaceNamespace = "init";
      };
    };
  };

  testScript = ''
    startAll();

    $peer0->waitForUnit("wireguard-wg0.service");
    $peer1->waitForUnit("wireguard-wg0.service");
    $peer2->waitForUnit("wireguard-wg0.service");
    $peer3->waitForUnit("wireguard-wg0.service");

    $peer0->succeed("ip -n ${socketNamespace} link show wg0");
    $peer1->succeed("ip -n ${interfaceNamespace} link show wg0");
    $peer2->succeed("ip -n ${interfaceNamespace} link show wg0");
    $peer3->succeed("ip link show wg0");
  '';
})