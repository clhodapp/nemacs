usage() {
  cat <<'EOF'
Usage: nemacs [options] COMMAND [-- NIX_ARGUMENT...]

Builds and activates a nemacs configuration published by a flake as
`nemacsConfigurations.<system>.<name>`. Activating a configuration
points its Nix profile at the editor and changes nothing else.

Commands:
  build         Build the activation package and link it at --out-link.
  switch        Build the configuration and activate it.
  generations   List the generations of the profile.
  rollback      Make the previous generation of the profile current.
  help          Print this text.

Options:
  -f, --flake REF[#NAME]   The flake that publishes the configuration, and
                           the name of the configuration (default: . and
                           default).
  -o, --out-link PATH      Where `build` links the activation package
                           (default: result).
  -h, --help               Print this text.

Arguments after `--` are passed to every `nix` command it runs.
EOF
}

die() {
  printf 'nemacs: %s\n' "$1" >&2
  exit 1
}

flake=.
name=default
out_link=result
command=
nix_args=()

while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  -f | --flake)
    [ $# -ge 2 ] || die "$1 needs a value"
    flake=${2%%#*}
    case "$2" in
    *'#'*) name=${2#*#} ;;
    esac
    [ -n "$flake" ] || flake=.
    [ -n "$name" ] || die "the name of the configuration after # is empty"
    shift 2
    ;;
  -o | --out-link)
    [ $# -ge 2 ] || die "$1 needs a value"
    out_link=$2
    shift 2
    ;;
  --)
    shift
    nix_args=("$@")
    break
    ;;
  -*)
    die "unknown option $1"
    ;;
  *)
    [ -z "$command" ] || die "unexpected argument $1"
    command=$1
    shift
    ;;
  esac
done

case "$command" in
help)
  usage
  exit 0
  ;;
build | switch | generations | rollback) ;;
'')
  usage >&2
  exit 2
  ;;
*)
  die "unknown command $command"
  ;;
esac

system=$(nix eval --impure --raw --expr builtins.currentSystem "${nix_args[@]}")
attr="$flake#nemacsConfigurations.$system.\"$name\""

# The path of the profile as the configuration publishes it, which may
# name $HOME.
profile_path() {
  local path
  path=$(nix eval --raw "$attr.profile.path" "${nix_args[@]}")
  printf '%s\n' "${path//\$HOME/$HOME}"
}

case "$command" in
build)
  nix build "$attr.activationPackage" --out-link "$out_link" "${nix_args[@]}"
  ;;
switch)
  activation=$(nix build "$attr.activationPackage" --no-link --print-out-paths "${nix_args[@]}")
  "$activation/activate"
  ;;
generations)
  nix profile history --profile "$(profile_path)" "${nix_args[@]}"
  ;;
rollback)
  nix profile rollback --profile "$(profile_path)" "${nix_args[@]}"
  ;;
esac
