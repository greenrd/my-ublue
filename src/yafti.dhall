let List/map =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/v23.0.0/Prelude/List/map
        sha256:dd845ffb4568d40327f2a817eb42d1c6138b929ca758d50bc33112ef3c885680

let List/foldLeft =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/v23.0.0/Prelude/List/foldLeft.dhall

let NonEmpty =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/v23.0.0/Prelude/NonEmpty/Type.dhall

let NonEmpty/make =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/v23.0.0/Prelude/NonEmpty/make.dhall

let Function/compose =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/v23.0.0/Prelude/Function/compose

let Optional/map =
      https://raw.githubusercontent.com/dhall-lang/dhall-lang/v23.0.0/Prelude/Optional/map.dhall

let `vscode variant` = "com.vscodium.codium"

let `vscode variant short` = "VSCodium"

let `test not present` =
      \(search : Text) -> "| grep " ++ search ++ " | wc -l | grep '^0\$'"

let `vscode config` =
          "~/.var/app/"
      ++  `vscode variant`
      ++  "/config/"
      ++  `vscode variant short`
      ++  "/User"

let `mkdir tree if absent` =
      \(`dir name` : Text) ->
            "([[ -d "
        ++  `dir name`
        ++  " ]] || mkdir --parents "
        ++  `dir name`
        ++  ")"

let seq =
      \(nel : NonEmpty Text) ->
        List/foldLeft
          Text
          nel.tail
          Text
          (\(x : Text) -> \(y : Text) -> x ++ " && " ++ y)
          nel.head

let `create file if absent` =
      \(`dir name` : Text) ->
      \(`file name` : Text) ->
      \(rest : Text) ->
        let `full name` = `dir name` ++ "/" ++ `file name`

        in
            seq
              ( NonEmpty/make
                Text
                (`mkdir tree if absent` `dir name`)
                ["([[ -f "
            ++  `full name`
            ++  " ]] || "
            ++  rest
            ++  "> "
            ++  `full name`]
              )

let in-place =
      \(cmd : Text) ->
      \(`file name` : Text) ->
        let `temp file name` = `file name` ++ ".tmp"

        in
            seq
              ( NonEmpty/make
                Text
                (cmd
            ++  " "
            ++  `file name`
            ++  " > "
            ++  `temp file name`)
            ["mv "
            ++  `temp file name`
            ++  " "
            ++  `file name`]
              )

let `in-place jq` = \(expr : Text) -> in-place ("jq '" ++ expr ++ "'")

let Assoc = \(a : Type) -> { mapKey : Text, mapValue : a }

let LabelledType = \(a : Type) -> { source : Text, values : a }

let Consent =
      { title : Text
      , condition : { run : Text }
      , description : Text
      , actions : List { run : Text }
      }

let Title =
      \(F : Type -> Type) ->
        { title : Text
        , icon : Text
        , links : Optional (F (Assoc { run : Text }))
        , description : Text
        }

let Group =
      \(F : Type -> Type) ->
        { description : Text, default : Bool, packages : F (Assoc Text) }

let `inside Group` =
      \(F : Type -> Type) ->
      \(G : Type -> Type) ->
      \(f : F (Assoc Text) -> G (Assoc Text)) ->
      \(g : Group F) ->
        { description = g.description
        , default = g.default
        , packages = f g.packages
        }

let duplicate = \(a : Type) -> List/map a (List a) (\(x : a) -> [ x ])

let Package =
      \(F : Type -> Type) ->
        { title : Text
        , show_terminal : Bool
        , package_manager : Text
        , package_manager_defaults : { user : Bool, system : Bool }
        , groups : List (Assoc (Group F))
        }

let `inside Assoc` =
      \(A : Type) ->
      \(B : Type) ->
      \(f : A -> B) ->
      \(a : Assoc A) ->
        { mapKey = a.mapKey, mapValue = f a.mapValue }

let List2D = \(A : Type) -> List (List A)

let `reformat Package` =
      \(p : Package List) ->
        { title = p.title
        , show_terminal = p.show_terminal
        , package_manager = p.package_manager
        , package_manager_defaults = p.package_manager_defaults
        , groups =
            List/map
              (Assoc (Group List))
              (Assoc (Group List2D))
              ( `inside Assoc`
                  (Group List)
                  (Group List2D)
                  (`inside Group` List List2D (duplicate (Assoc Text)))
              )
              p.groups
        }

let `reformat Title` =
      \(t : Title List) ->
        { title = t.title
        , icon = t.icon
        , description = t.description
        , links =
            Optional/map
              (List (Assoc { run : Text }))
              (List2D (Assoc { run : Text }))
              (duplicate (Assoc { run : Text }))
              t.links
        }

let Screen =
      < ConsentScreen : Consent
      | TitleScreen : Title List2D
      | PackageScreen : Package List2D
      >

let `make PackageScreen` =
      Function/compose
        (Package List)
        (Package List2D)
        Screen
        `reformat Package`
        Screen.PackageScreen

let `make TitleScreen` =
      Function/compose
        (Title List)
        (Title List2D)
        Screen
        `reformat Title`
        Screen.TitleScreen

let label =
      \(s : Screen) ->
        { source =
                "yafti.screen."
            ++  merge
                  { ConsentScreen = \(c : Consent) -> "consent"
                  , TitleScreen = \(t : Title List2D) -> "title"
                  , PackageScreen = \(p : Package List2D) -> "package"
                  }
                  s
        , values = s
        }

let `check for flathub`
    : Text -> Assoc Screen
    = \(type : Text) ->
        let `type option` = "--" ++ type

        let `repo name` = "flathub"

        in  { mapKey = "aac-check-" ++ type ++ "-" ++ `repo name`
            , mapValue =
                Screen.ConsentScreen
                  { title =
                          "Missing "
                      ++  `repo name`
                      ++  " Repository ("
                      ++  type
                      ++  ")"
                  , condition.run
                    =
                          "flatpak remotes "
                      ++  `type option`
                      ++  " --columns=name "
                      ++  `test not present` `repo name`
                  , description =
                          "We have detected that you don't have the "
                      ++  `repo name`
                      ++  " repository on your "
                      ++  type
                      ++  ". We will now add that repository to your "
                      ++  type
                      ++  " list."
                  , actions =
                    [ { run =
                              "flatpak remote-add --if-not-exists "
                          ++  `type option`
                          ++  " "
                          ++  `repo name`
                          ++  " https://flathub.org/repo/flathub.flatpakrepo"
                      }
                    ]
                  }
            }

let `bin directory` = "~/.local/bin"

let shellcheck = `bin directory` ++ "/shellcheck"

let `scope directory` =
      "~/.config/systemd/user/app-" ++ `vscode variant` ++ "-.scope.d"

let `firstboot directory` = "/usr/share/ublue-os/firstboot"

let `with temp file` =
      \(cmds : Text -> List Text) ->
        let `temp var` = "temp_file"

        in    [ `temp var` ++ "=\$(mktemp --tmpdir=/tmp)" ]
            # cmds `temp var`
            # [ "rm \$" ++ `temp var` ]

in  { title = "Welcome to my-uBlue"
    , properties.mode = "run-on-change"
    , screens =
        List/map
          (Assoc Screen)
          (Assoc (LabelledType Screen))
          (`inside Assoc` Screen (LabelledType Screen) label)
          (   [ { mapKey = "aaa-first-screen"
                , mapValue =
                    `make TitleScreen`
                      { title = "Welcome to my-uBlue (Alpha)"
                      , icon = "/path/to/icon"
                      , links = None (List (Assoc { run : Text }))
                      , description =
                          "This guided installer will help you get started with your new system."
                      }
                }
              , { mapKey = "aab-can-we-modify-your-flatpaks"
                , mapValue =
                    Screen.ConsentScreen
                      { title = "Welcome, Traveler!"
                      , condition.run
                        = "flatpak remotes --columns=name | grep fedora"
                      , description =
                          "We have detected the limited, Fedora-provided Flatpak remote on your system, whose applications are usually missing important codecs and other features. This step will therefore remove all basic Fedora Flatpaks from your system! We will instead switch all core Flatpak applications over to the vastly superior, unfiltered Flathub. If you don't want to do this, simply exit this installer."
                      , actions =
                        [ { run =
                              "flatpak remote-delete --system --force fedora"
                          }
                        , { run = "flatpak remote-delete --user --force fedora"
                          }
                        , { run =
                              "flatpak remove --system --noninteractive --all"
                          }
                        , { run =
                              "flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo"
                          }
                        , { run =
                              "flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo"
                          }
                        ]
                      }
                }
              , { mapKey = "applications"
                , mapValue =
                    `make PackageScreen`
                      { title = "Application Installer"
                      , show_terminal = True
                      , package_manager = "yafti.plugin.flatpak"
                      , package_manager_defaults =
                        { user = False, system = True }
                      , groups =
                        [ { mapKey = "System Apps"
                          , mapValue =
                            { description =
                                "System applications for all desktop environments."
                            , default = True
                            , packages =
                              [ { mapKey = "Deja Dup Backups"
                                , mapValue = "org.gnome.DejaDup"
                                }
                              , { mapKey = "Fedora Media Writer"
                                , mapValue = "org.fedoraproject.MediaWriter"
                                }
                              , { mapKey = "Flatseal (Permission Manager)"
                                , mapValue = "com.github.tchx84.Flatseal"
                                }
                              , { mapKey = "Font Downloader"
                                , mapValue = "org.gustavoperedo.FontDownloader"
                                }
                              , { mapKey = "Mozilla Firefox"
                                , mapValue = "org.mozilla.firefox"
                                }
                              ]
                            }
                          }
                        , { mapKey = "Web Browsers"
                          , mapValue =
                            { description =
                                "Additional browsers to complement or replace Firefox."
                            , default = False
                            , packages =
                              [ { mapKey = "Brave"
                                , mapValue = "com.brave.Browser"
                                }
                              , { mapKey = "Google Chrome"
                                , mapValue = "com.google.Chrome"
                                }
                              , { mapKey = "Microsoft Edge"
                                , mapValue = "com.microsoft.Edge"
                                }
                              , { mapKey = "Opera"
                                , mapValue = "com.opera.Opera"
                                }
                              ]
                            }
                          }
                        , { mapKey = "Gaming"
                          , mapValue =
                            { description = "Rock and Stone!"
                            , default = False
                            , packages =
                              [ { mapKey = "Bottles"
                                , mapValue = "com.usebottles.bottles"
                                }
                              , { mapKey = "Discord"
                                , mapValue = "com.discordapp.Discord"
                                }
                              , { mapKey = "Heroic Games Launcher"
                                , mapValue = "com.heroicgameslauncher.hgl"
                                }
                              , { mapKey = "Steam"
                                , mapValue = "com.valvesoftware.Steam"
                                }
                              , { mapKey = "Gamescope (Utility)"
                                , mapValue =
                                    "com.valvesoftware.Steam.Utility.gamescope"
                                }
                              , { mapKey = "MangoHUD (Utility)"
                                , mapValue =
                                    "org.freedesktop.Platform.VulkanLayer.MangoHud//22.08"
                                }
                              , { mapKey = "SteamTinkerLaunch (Utility)"
                                , mapValue =
                                    "com.valvesoftware.Steam.Utility.steamtinkerlaunch"
                                }
                              , { mapKey = "Proton Updater for Steam"
                                , mapValue = "net.davidotek.pupgui2"
                                }
                              ]
                            }
                          }
                        , { mapKey = "Office"
                          , mapValue =
                            { description = "Boost your productivity."
                            , default = False
                            , packages =
                              [ { mapKey = "LibreOffice"
                                , mapValue = "org.libreoffice.LibreOffice"
                                }
                              , { mapKey = "OnlyOffice"
                                , mapValue = "org.onlyoffice.desktopeditors"
                                }
                              , { mapKey = "LogSeq"
                                , mapValue = "com.logseq.Logseq"
                                }
                              , { mapKey = "Slack"
                                , mapValue = "com.slack.Slack"
                                }
                              , { mapKey = "Standard Notes"
                                , mapValue = "org.standardnotes.standardnotes"
                                }
                              , { mapKey = "Thunderbird Email"
                                , mapValue = "org.mozilla.Thunderbird"
                                }
                              , { mapKey = "Zotero"
                                , mapValue = "org.zotero.Zotero"
                                }
                              ]
                            }
                          }
                        , { mapKey = "Streaming"
                          , mapValue =
                            { description = "Stream to the Internet."
                            , default = False
                            , packages =
                              [ { mapKey = "OBS Studio"
                                , mapValue = "com.obsproject.Studio"
                                }
                              , { mapKey = "VkCapture for OBS"
                                , mapValue =
                                    "com.obsproject.Studio.OBSVkCapture"
                                }
                              , { mapKey = "Gstreamer for OBS"
                                , mapValue =
                                    "com.obsproject.Studio.Plugin.Gstreamer"
                                }
                              , { mapKey = "Gstreamer VAAPI for OBS"
                                , mapValue =
                                    "com.obsproject.Studio.Plugin.GStreamerVaapi"
                                }
                              , { mapKey = "Boatswain for Streamdeck"
                                , mapValue = "com.feaneron.Boatswain"
                                }
                              ]
                            }
                          }
                        ]
                      }
                }
              , { mapKey = "integrate-zotero-logseq"
                , mapValue = 
                    Screen.ConsentScreen
                      { title = "Integrate Zotero into LogSeq"
                      , condition.run
                        = "(flatpak list | grep -F org.zotero.Zotero) && (flatpak list | grep -F com.logseq.Logseq)"
                      , description =
                          "We have detected that you have installed both Zotero and LogSeq. We will now integrate Zotero into LogSeq."
                      , actions =
                      
                       }
                }
              , { mapKey = "z-final-screen"
                , mapValue =
                    `make TitleScreen`
                      { title = "All done!"
                      , icon = "/path/to/icon"
                      , links = Some
                        [ { mapKey = "Install More Applications"
                          , mapValue.run = "/usr/bin/plasma-discover"
                          }
                        ]
                      , description =
                          "Thanks for trying my-uBlue, I hope you enjoy it!"
                      }
                }
              ]
            # List/map
                Text
                (Assoc Screen)
                `check for flathub`
                [ "system", "user" ]
            # [ { mapKey = "aad-check-distrobox-fedora"
                , mapValue =
                    Screen.ConsentScreen
                      { title = "Missing Fedora Distrobox"
                      , condition.run
                        = "distrobox list " ++ `test not present` "fedora"
                      , description =
                          "We have detected that you don't have a Fedora Distrobox set up. We will now create one."
                      , actions =
                        [ { run =
                              seq
                                ( NonEmpty/make
                                    Text
                                    (     "distrobox assemble create --file "
                                      ++  `firstboot directory`
                                      ++  "/distrobox.ini"
                                    )
                                    ( `with temp file`
                                        ( \(`temp var` : Text) ->
                                            [     "cp "
                                              ++  `firstboot directory`
                                              ++  "/setup-emacs.el \$"
                                              ++  `temp var`
                                            ,     "distrobox enter fedora -- emacs --fg-daemon --no-desktop --load \$"
                                              ++  `temp var`
                                            ]
                                        )
                                    )
                                )
                          }
                        ]
                      }
                }
              , { mapKey = "aae-check-vscode"
                , mapValue =
                    Screen.ConsentScreen
                      { title = "Development environment"
                      , condition.run
                        =
                              "flatpak list "
                          ++  `test not present` ("-F " ++ `vscode variant`)
                      , description =
                              "We have detected that you don't have "
                          ++  `vscode variant short`
                          ++  " (the open source build of Visual Studio Code) installed. We will now install that with batteries included."
                      , actions =
                        [ { run =
                              seq
                                ( NonEmpty/make
                                    Text
                                    (`mkdir tree if absent` `bin directory`)
                                    [     "cp /usr/share/shellcheck "
                                      ++  `bin directory`
                                    , "chmod +x " ++ shellcheck
                                    ]
                                )
                          }
                        , { run =
                              seq
                                ( NonEmpty/make
                                    Text
                                    ( `create file if absent`
                                        `vscode config`
                                        "settings.json"
                                        "echo '{}'"
                                    )
                                    ( List/map
                                        Text
                                        Text
                                        ( \(subst : Text) ->
                                            `in-place jq`
                                              subst
                                              (     `vscode config`
                                                ++  "/settings.json"
                                              )
                                        )
                                        [     ".bashIde.shellcheckPath = \""
                                          ++  shellcheck
                                          ++  "\""
                                        , ".bashIde.explainshellEndpoint = \"http://localhost:5000\""
                                        ]
                                    )
                                )
                          }
                        , { run =
                              seq
                                ( NonEmpty/make
                                    Text
                                    "podman container create --name explainshell -p 5000:5000 ghcr.io/idank/idank/explainshell:master"
                                    [ "podman generate systemd explainshell >es.service"
                                    , "sed -i -e '/WantedBy=default\\.target/d' es.service"
                                    , `mkdir tree if absent` `scope directory`
                                    , "mv es.service .config/systemd/user/explainshell.service"
                                    ,     "cp /usr/share/vscode.conf "
                                      ++  `scope directory`
                                    , "systemctl --user daemon-reload"
                                    ]
                                )
                          }
                        , { run =
                              seq
                                ( NonEmpty/make
                                    Text
                                    (     "flatpak install -y --system "
                                      ++  `vscode variant`
                                    )
                                    [     "flatpak run "
                                      ++  `vscode variant`
                                      ++  " --install-extension mads-hartmann.bash-ide-vscode"
                                    ]
                                )
                          }
                        ]
                      }
                }
              ]
          )
    }
