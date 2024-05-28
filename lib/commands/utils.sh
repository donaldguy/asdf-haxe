arch_github_name() {
  case "$(uname -m)" in
    i?86) echo "32";;
    x86_64|amd64) echo "64";;
    aarch64) echo "arm64";;
    arm*) echo "raspi";;
    *)  ;;
  esac
}

os_github_name() {
  case "$(uname -s)" in
    Darwin) echo "osx" ;; 
    Linux) echo "linux" ;;
    CYGWIN*|MINGW*|MSYS*) echo "win" ;;
  esac
}

fail() {
  printf "\e[31mFail:\e[m %s" "$*" >&2
  exit 1
}

fail_arch_unknown() {
  fail "CPU architecture was not supported at this point!\n"\
      "for arm64, try >= 4.3.4.\n"\ 
      "for armhf, try 3.1.X;""for other non-x86, I guess go for source?"
}

fail_arch_late_32() {
  fail "They had stopped shipping 32 bit binaries by this point:\n"\
      "For macOS: last was 3.0.0\n"\
      "For Linux: last was 3.4.2\n"
}

install_from_github() {
  local version=$1
  local suffix=$2
  local install_path=$3
  local ext="tar.gz"

  if [[ "$suffix" =~ ^"win" ]]; then
    ext="zip"
  fi 

  local download_url="https://github.com/HaxeFoundation/haxe/releases/download/${version}/haxe-${version#v*}-${suffix}.${ext}"

  install_from_url "$download_url" "$install_path" "haxe-${version}.${ext}"
}

install_from_url() {
  local download_url=$1
  local install_path=$2
  local temp_file=$3

  local source_path="${install_path}/${temp_file}"
  local distination_path="${install_path}/bin"

  (
    echo "∗ Downloading Haxe binaries..."
    curl --silent --location --output "$source_path" -C - "$download_url" || fail "Could not download Haxe $version source"
    mkdir -p "$distination_path"
    if [[ "$tempfile" =~ ".zip"$ ]]; then
      unzip "$source_path" -d "$distination_path"
      mv haxe* the_dir || mv build the_dir
      mv the_dir/* . 
      rmdir the_dir
    else
      tar -zxf "$source_path" -C "$distination_path" --strip-components=1
    fi
    rm "$source_path"
    echo "The installation was successful!"
    echo
    echo "If you get dylib errors when running haxelib be sure to read https://github.com/asdf-community/asdf-haxe#troubleshooting"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred"
  )
}

standard_x86_install() {
  local version=$1
  local os=$2
  local arch=$3
  local install_path=$4

  if [[ "$arch" = "64" ]]; then 
    if [[ "$os" = "osx" ]]; then
      install_from_github "$version" "${os}" "$install_path";
    else
      install_from_github "$version" "${os}64" "$install_path";
    end
  elif [[ "$arch" = "32" ]]; then
    if [[ "$os" != "win" ]]; then fail_arch_late_32; fi 
    install_from_github "$version" "${os}" "$install_path";
  else
    fail_arch_unknown
  fi
}

# this is pretty arcane to read, but usage should make it make sense. 
#or see the examples in top of gist: https://gist.github.com/donaldguy/1a18aa3a639ced600f592ad327dcd2c2
version_endpoints_compare() {
  local input_verson;
  input_version="$1"; 
  shift;
  local input_line_included=""
  
  local constraint_sort_lines=()
  local constraints=()
  
  for c in "$@"; do 
    if [[ "$c" =~ ^"<=" ]]; then
      constraint_sort_lines+=("${c#<=*}C")
      constraints+=("$c")
    elif [[ "$c" =~ ^"=" ]]; then
      constraint_sort_lines+=("${c#=*}A")
      if [[ -z "$input_line_included" ]]; then
        constraint_sort_lines+=("${input_version}B input_version")
        constraints+=("other")
        input_line_included="yes"
      fi
      constraints+=("$c")
    elif [[ "$c" =~ ^">=" ]]; then
      if [[ -z "$input_line_included" ]]; then
        constraint_sort_lines+=("${input_version}B input_version")
        constraints+=("other")
        input_line_included="yes"
      fi
      constraint_sort_lines+=("${c#>=*}")
      constraints+=("$c")
    else
      fail "Unrecognized constraint: '$c'. Should start with <=, =, or >=";
    fi
  done

  line_after_sort=$(printf "%s\n" "${constraint_sort_lines[@]}" | sort --version-sort | \
    grep --line-number "input_version" | cut -f1 -d: )

  echo "${constraints[line_after_sort - 1]}"
}