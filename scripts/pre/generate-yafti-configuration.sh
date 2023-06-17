#! /bin/bash

# TODO: Using bash to generate bash code is a little tricky in places - switch to something cleaner

# Tweakable things
export VSCODE_VARIANT=com.vscodium.codium
export VSCODE_VARIANT_SHORT=VSCodium

# Common code snippets
export not_present="wc -l | grep '^0$'"

# Computed values
export VSCODE_CONFIG="~/.var/app/$VSCODE_VARIANT/config/$VSCODE_VARIANT_SHORT/User/settings.json"

# Functions
mkdir_tree_if_absent () {
  echo "([[ -d $1 ]] || mkdir --parents $1)"
}

create_file_if_absent () {
  local filename=$1
  shift
  echo "$(mkdir_tree_if_absent $(dirname $filename)) && ([[ -f $filename ]] ||" "$@" "> $filename)"
}

in-place_jq () {
  echo "jq |$1| $2 > $2.tmp && mv $2.tmp $2"|tr "|" "'"
}

cat > /usr/share/ublue-os/firstboot/yafti.yml <<EOF
title: Welcome to uBlue
properties:
  mode: "run-on-change"
screens:
  first-screen:
    source: yafti.screen.title
    values:
      title: "Welcome to my-uBlue (Alpha)"
      icon: "/path/to/icon"
      description: |
        This guided installer will help you get started with your new system.
  can-we-modify-your-flatpaks:
    source: yafti.screen.consent
    values:
      title: Welcome, Traveler!
      condition:
        run: flatpak remotes --columns=name | grep fedora
      description: |
        We have detected the limited, Fedora-provided Flatpak remote on your system, whose applications are usually missing important codecs and other features. This step will therefore remove all basic Fedora Flatpaks from your system! We will instead switch all core Flatpak applications over to the vastly superior, unfiltered Flathub. If you don't want to do this, simply exit this installer.
      actions:
        - run: flatpak remote-delete --system --force fedora
        - run: flatpak remote-delete --user --force fedora
        - run: flatpak remove --system --noninteractive --all
        - run: flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo
        - run: flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
  check-system-flathub:
    source: yafti.screen.consent
    values:
      title: Missing Flathub Repository (System)
      condition:
        run: flatpak remotes --system --columns=name | grep flathub | $not_present
      description: |
        We have detected that you don't have Flathub's repository on your system. We will now add that repository to your system-wide list.
      actions:
        - run: flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo
  check-user-flathub:
    source: yafti.screen.consent
    values:
      title: Missing Flathub Repository (User)
      condition:
        run: flatpak remotes --user --columns=name | grep flathub | $not_present
      description: |
        We have detected that you don't have Flathub's repository on your current user account. We will now add that repository to your account.
      actions:
        - run: flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
  check-distrobox-fedora:
    source: yafti.screen.consent
    values:
      title: Missing Fedora Distrobox
      condition:
        run: distrobox list | grep fedora | $not_present
      description: |
        We have detected that you don't have a Fedora Distrobox set up. We will now create one.
      actions:
        - run: distrobox create --image quay.io/fedora/fedora:38 --name fedora
  check-vscode:
    source: yafti.screen.consent
    values:
      title: Development environment
      condition:
        run: flatpak list | grep -F $VSCODE_VARIANT | $not_present
      description: |
        We have detected that you don't have $VSCODE_VARIANT_SHORT (the open source build of Visual Studio Code) installed. We will now install that with batteries included.
      actions:
        - run: "$(mkdir_tree_if_absent "~/.local/bin") && cp /usr/share/shellcheck ~/.local/bin && chmod +x ~/.local/bin/shellcheck"
        - run: distrobox enter fedora -- sudo dnf install -y shellcheck
        - run: |
            $(create_file_if_absent "$VSCODE_CONFIG" echo '{}') && \
            $(in-place_jq '.bashIde.shellcheckPath = "~/.local/bin/shellcheck"' $VSCODE_CONFIG) && \
            $(in-place_jq '.bashIde.explainshellEndpoint = "http://localhost:5000"' $VSCODE_CONFIG)
        - run: |
            podman container create --name explainshell -p 5000:5000 ghcr.io/idank/idank/explainshell:master && \
            podman generate systemd explainshell >es.service && \
            sed -i -e '/WantedBy=default\.target/d' es.service && \
            $(mkdir_tree_if_absent "~/.config/systemd/user/app-${VSCODE_VARIANT}-.scope.d") && \
            mv es.service .config/systemd/user/explainshell.service && \
            cp /usr/share/vscode.conf .config/systemd/user/app-${VSCODE_VARIANT}-.scope.d && \
            systemctl --user daemon-reload
        - run: flatpak install -y --system $VSCODE_VARIANT && flatpak run $VSCODE_VARIANT --install-extension mads-hartmann.bash-ide-vscode
  applications:
    source: yafti.screen.package
    values:
      title: Application Installer
      show_terminal: true
      package_manager: yafti.plugin.flatpak
      package_manager_defaults:
        user: false
        system: true
      groups:
        System Apps:
          description: System applications for all desktop environments.
          default: true
          packages:
            - Deja Dup Backups: org.gnome.DejaDup
            - Fedora Media Writer: org.fedoraproject.MediaWriter
            - Flatseal (Permission Manager): com.github.tchx84.Flatseal
            - Font Downloader: org.gustavoperedo.FontDownloader
            - Mozilla Firefox: org.mozilla.firefox
        Web Browsers:
          description: Additional browsers to complement or replace Firefox.
          default: false
          packages:
            - Brave: com.brave.Browser
            - Google Chrome: com.google.Chrome
            - Microsoft Edge: com.microsoft.Edge
            - Opera: com.opera.Opera
        Gaming:
          description: "Rock and Stone!"
          default: false
          packages:
            - Bottles: com.usebottles.bottles
            - Discord: com.discordapp.Discord
            - Heroic Games Launcher: com.heroicgameslauncher.hgl
            - Steam: com.valvesoftware.Steam
            - Gamescope (Utility): com.valvesoftware.Steam.Utility.gamescope
            - MangoHUD (Utility): org.freedesktop.Platform.VulkanLayer.MangoHud//22.08
            - SteamTinkerLaunch (Utility): com.valvesoftware.Steam.Utility.steamtinkerlaunch
            - Proton Updater for Steam: net.davidotek.pupgui2
        Office:
          description: Boost your productivity.
          default: false
          packages:
            - LibreOffice: org.libreoffice.LibreOffice
            - OnlyOffice: org.onlyoffice.desktopeditors
            - LogSeq: com.logseq.Logseq
            - Slack: com.slack.Slack
            - Standard Notes: org.standardnotes.standardnotes
            - Thunderbird Email: org.mozilla.Thunderbird
        Streaming:
          description: Stream to the Internet.
          default: false
          packages:
            - OBS Studio: com.obsproject.Studio
            - VkCapture for OBS: com.obsproject.Studio.OBSVkCapture
            - Gstreamer for OBS: com.obsproject.Studio.Plugin.Gstreamer
            - Gstreamer VAAPI for OBS: com.obsproject.Studio.Plugin.GStreamerVaapi
            - Boatswain for Streamdeck: com.feaneron.Boatswain

  final-screen:
    source: yafti.screen.title
    values:
      title: "All done!"
      icon: "/path/to/icon"
      links:
        - "Install More Applications":
            run: /usr/bin/plasma-discover
      description: |
        Thanks for trying my-uBlue, I hope you enjoy it!
EOF