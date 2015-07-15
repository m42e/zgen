#!/bin/zsh
autoload -U regexp-replace

local ZGEN_SOURCE="$(cd "$(dirname "${0}")" && pwd -P)"


if [[ -z "${ZGEN_DIR}" ]]; then
    ZGEN_DIR="${HOME}/.zgen"
fi

if [[ -z "${ZGEN_INIT}" ]]; then
    ZGEN_INIT="${ZGEN_DIR}/init.zsh"
fi

if [[ -z "${ZGEN_LOADED}" ]]; then
    ZGEN_LOADED=()
fi

if [[ -z "${ZGEN_PREZTO_OPTIONS}" ]]; then
    ZGEN_PREZTO_OPTIONS=()
fi

if [[ -z "${ZGEN_PREZTO_LOAD}" ]]; then
    ZGEN_PREZTO_LOAD=()
fi

if [[ -z "${ZGEN_COMPLETIONS}" ]]; then
    ZGEN_COMPLETIONS=()
fi

if [[ -z "${ZGEN_USE_PREZTO}" ]]; then
	ZGEN_USE_PREZTO=0
fi

if [[ -z "${ZGEN_PREZTO_LOAD_DEFAULT}" ]]; then
	ZGEN_PREZTO_LOAD_DEFAULT=1
fi

if [[ -z "${ZGEN_OH_MY_ZSH_REPO}" ]]; then
    ZGEN_OH_MY_ZSH_REPO=robbyrussell
fi

if [[ "${ZGEN_OH_MY_ZSH_REPO}" != */* ]]; then
    ZGEN_OH_MY_ZSH_REPO="${ZGEN_OH_MY_ZSH_REPO}/oh-my-zsh"
fi

if [[ -z "${ZGEN_OH_MY_ZSH_BRANCH}" ]]; then
    ZGEN_OH_MY_ZSH_BRANCH=master
fi

if [[ -z "${ZGEN_PREZTO_REPO}" ]]; then
    ZGEN_PREZTO_REPO=sorin-ionescu
fi

if [[ "${ZGEN_PREZTO_REPO}" != */* ]]; then
    ZGEN_PREZTO_REPO="${ZGEN_PREZTO_REPO}/prezto"
fi

if [[ -z "${ZGEN_PREZTO_BRANCH}" ]]; then
    ZGEN_PREZTO_BRANCH=master
fi

-zgen-encode-url () {
    # Remove characters from a url that don't work well in a filename.
    # Inspired by -anti-get-clone-dir() method from antigen.
    autoload -U regexp-replace
    regexp-replace 1 '/' '-SLASH-'
    regexp-replace 1 ':' '-COLON-'
    regexp-replace 1 '\|' '-PIPE-'
    echo $1
}

-zgen-get-clone-dir() {
    local repo="${1}"
    local branch="${2:-master}"

    if [[ -e "${repo}/.git" ]]; then
        echo "${ZGEN_DIR}/local/$(basename ${repo})-${branch}"
    else
        # Repo directory will be location/reponame
        local reponame="$(basename ${repo})"
        # Need to encode incase it is a full url with characters that don't
        # work well in a filename.
        local location="$(-zgen-encode-url $(dirname ${repo}))"
        repo="${location}/${reponame}"
        echo "${ZGEN_DIR}/${repo}-${branch}"
    fi
}

-zgen-get-clone-url() {
    local repo="${1}"

    if [[ -e "${repo}/.git" ]]; then
        echo "${repo}"
    else
        # Sourced from antigen url resolution logic.
        # https://github.com/zsh-users/antigen/blob/master/antigen.zsh
        # Expand short github url syntax: `username/reponame`.
        if [[ $repo != git://* &&
              $repo != https://* &&
              $repo != http://* &&
              $repo != ssh://* &&
              $repo != git@github.com:*/*
              ]]; then
            repo="https://github.com/${repo%.git}.git"
        fi
        echo "${repo}"
    fi
}

zgen-clone() {
    local repo="${1}"
    local branch="${2:-master}"
    local url="$(-zgen-get-clone-url ${repo})"
    local dir="$(-zgen-get-clone-dir ${repo} ${branch})"

    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
        git clone --depth=1 --recursive -b "${branch}" "${url}" "${dir}"
    fi
}

-zgen-add-to-fpath() {
    local completion_path="${1}"

    # Add the directory to ZGEN_COMPLETIONS array if not present
    if [[ ! "${ZGEN_COMPLETIONS[@]}" =~ ${completion_path} ]]; then
        ZGEN_COMPLETIONS+=("${completion_path}")
    fi
}

-zgen-source() {
    local file="${1}"

    source "${file}"

    # Add to ZGEN_LOADED array if not present
    if [[ ! "${ZGEN_LOADED[@]}" =~ "${file}" ]]; then
        ZGEN_LOADED+=("${file}")
    fi

    completion_path="$(dirname ${file})"

    -zgen-add-to-fpath "${completion_path}"
}

-zgen-prezto-option(){
	local module=${1}
	shift
	local params="$*"
	local cmd="zstyle ':prezto:module:${module}' $params"

	# execute in place
	eval $cmd

    if [[ ! "${ZGEN_PREZTO_OPTIONS[@]}" =~ "${cmd}" ]]; then
        ZGEN_PREZTO_OPTIONS+=("${cmd}")
    fi
}

-zgen-prezto-load(){
	local params="$*"
	local cmd="pmodload ${params[@]}"

	# execute in place
	eval $cmd

    if [[ ! "${ZGEN_PREZTO[@]}" =~ "${cmd}" ]]; then
        ZGEN_PREZTO_LOAD+=("${cmd}")
    fi
}

zgen-init() {
    if [[ -f "${ZGEN_INIT}" ]]; then
        source "${ZGEN_INIT}"
    fi
}

zgen-reset() {
    echo "zgen: Deleting ${ZGEN_INIT}"
    if [[ -f "${ZGEN_INIT}" ]]; then
        rm "${ZGEN_INIT}"
    fi
}

zgen-update() {
    for repo in "${ZGEN_DIR}"/*/*; do
        echo "Updating ${repo}"
        (cd "${repo}" \
            && git pull \
            && git submodule update --recursive)
    done
    zgen-reset
}

zgen-save() {
    echo "zgen: Creating ${ZGEN_INIT}"

    echo "#" >! "${ZGEN_INIT}"
    echo "# Generated by zgen." >> "${ZGEN_INIT}"
    echo "# This file will be overwritten the next time you run zgen save" >> "${ZGEN_INIT}"
    echo >> "${ZGEN_INIT}"
    echo "ZSH=$(-zgen-get-zsh)" >> "${ZGEN_INIT}"
    if [[ ${ZGEN_USE_PREZTO} == 1 ]]; then
        echo >> "${ZGEN_INIT}"
        echo "# init prezto" >> "${ZGEN_INIT}"
        for option in "${ZGEN_PREZTO_OPTIONS[@]}"; do
            echo "${option}" >> "${ZGEN_INIT}"
        done
    fi

    echo >> "${ZGEN_INIT}"
    echo "#" >> "${ZGEN_INIT}"
    for file in "${ZGEN_LOADED[@]}"; do
        echo "source \"${(q)file}\"" >> "${ZGEN_INIT}"
    done

    # Set up fpath
    echo >> "${ZGEN_INIT}"
    echo "#" >> "${ZGEN_INIT}"
    echo "# Add our plugins and completions to fpath">> "${ZGEN_INIT}"
    echo "#" >> "${ZGEN_INIT}"
    echo "fpath=(${(q)ZGEN_COMPLETIONS[@]} \${fpath})" >> "${ZGEN_INIT}"


    # load prezto modules
    if [[ ${ZGEN_USE_PREZTO} == 1 ]]; then
        echo >> "${ZGEN_INIT}"
        echo "# init prezto" >> "${ZGEN_INIT}"
        for module in "${ZGEN_PREZTO_LOAD[@]}"; do
            echo "${module}" >> "${ZGEN_INIT}"
        done
    fi

    zgen-apply --verbose
}

zgen-apply() {
  fpath=(${(q)ZGEN_COMPLETIONS[@]} ${fpath})
  [[ "$1" == --verbose ]] && echo "zgen: Creating ${ZGEN_DIR}/zcompdump"
  compinit -d "${ZGEN_DIR}/zcompdump"
}

zgen-completions() {
    echo "zgen: 'completions' is deprecated, please use 'load' instead"

    zgen-load "${@}"
}

-zgen-path-contains() {
  setopt localoptions nonomatch nocshnullglob nonullglob;
  [ -e "$1"/*"$2"(.,@[1]) ]
}

-zgen-get-zsh(){
	if [[ ${ZGEN_USE_PREZTO} == 1 ]]; then
		echo "$(-zgen-get-clone-dir "$ZGEN_PREZTO_REPO" "$ZGEN_PREZTO_BRANCH")"
	else
		echo "$(-zgen-get-clone-dir "$ZGEN_OH_MY_ZSH_REPO" "$ZGEN_OH_MY_ZSH_BRANCH")"
	fi
}

zgen-load() {
    if [[ "$#" == 1 && ("${1[1]}" == '/' || "${1[1]}" == '.' ) ]]; then
      local location="${1}"
    else
      local repo="${1}"
      local file="${2}"
      local branch="${3:-master}"
      local dir="$(-zgen-get-clone-dir ${repo} ${branch})"
      local location="${dir}/${file}"
      location=${location%/}

      # clone repo if not present
      if [[ ! -d "${dir}" ]]; then
          zgen-clone "${repo}" "${branch}"
      fi
    fi

    # source the file
    if [[ -f "${location}" ]]; then
        -zgen-source "${location}"

    # Prezto modules have init.zsh files
    elif [[ -f "${location}/init.zsh" ]]; then
        -zgen-source "${location}/init.zsh"

    elif [[ -f "${location}.zsh-theme" ]]; then
        -zgen-source "${location}.zsh-theme"

    elif [[ -f "${location}.theme.zsh" ]]; then
        -zgen-source "${location}.theme.zsh"

    elif [[ -f "${location}.zshplugin" ]]; then
        -zgen-source "${location}.zshplugin"

    elif [[ -f "${location}.zsh.plugin" ]]; then
        -zgen-source "${location}.zsh.plugin"

    # Classic oh-my-zsh plugins have foo.plugin.zsh
    elif -zgen-path-contains "${location}" ".plugin.zsh" ; then
        for script (${location}/*\.plugin\.zsh(N)) -zgen-source "${script}"

    elif -zgen-path-contains "${location}" ".zsh" ; then
        for script (${location}/*\.zsh(N)) -zgen-source "${script}"

    elif -zgen-path-contains "${location}" ".sh" ; then
        for script (${location}/*\.sh(N)) -zgen-source "${script}"

    # Completions
    elif [[ -d "${location}" ]]; then
        -zgen-add-to-fpath "${location}"

    else
        echo "zgen: Failed to load ${dir:-$location}"
    fi
}

zgen-loadall() {
    # shameless copy from antigen

    # Bulk add many bundles at one go. Empty lines and lines starting with a `#`
    # are ignored. Everything else is given to `zgen-load` as is, no
    # quoting rules applied.

    local line

    grep '^[[:space:]]*[^[:space:]#]' | while read line; do
        # Using `eval` so that we can use the shell-style quoting in each line
        # piped to `antigen-bundles`.
        eval "zgen-load $line"
    done
}

zgen-saved() {
    [[ -f "${ZGEN_INIT}" ]] && return 0 || return 1
}

zgen-list() {
    if [[ -f "${ZGEN_INIT}" ]]; then
        cat "${ZGEN_INIT}"
    else
        echo "Zgen init.zsh missing, please use zgen save and then restart your shell."
    fi
}

zgen-selfupdate() {
    if [[ -e "${ZGEN_SOURCE}/.git" ]]; then
        (cd "${ZGEN_SOURCE}" \
            && git pull)
    else
        echo "zgen is not running from a git repository, so it is not possible to selfupdate"
        return 1
    fi
}

zgen-oh-my-zsh() {
    local repo="$ZGEN_OH_MY_ZSH_REPO"
    local file="${1:-oh-my-zsh.sh}"

    zgen-load "${repo}" "${file}"
}

zgen-prezto() {
    local repo="$ZGEN_PREZTO_REPO"
    local file="${1:-init.zsh}"

	# load prezto itself
	if [[ $# == 0 ]]; then
		ZGEN_USE_PREZTO=1
		zgen-load "${repo}" "${file}"
		if [[ ! -h ${ZDOTDIR:-$HOME}/.zprezto ]]; then
			local dir="$(-zgen-get-clone-dir ${repo} ${ZGEN_PREZTO_BRANCH})"
			ln -s "${dir}" "${ZDOTDIR:-$HOME}/.zprezto"
		fi
		if [[ ${ZGEN_PREZTO_LOAD_DEFAULT} != 0 ]]; then
			-zgen-prezto-load "'environment' 'terminal' 'editor' 'history' 'directory' 'spectrum' 'utility' 'completion' 'prompt'"
		fi

	# this is a prezto module
	elif [[ $# == 1 ]]; then
		local module=${file}
		if [[ -z ${file} ]]; then
			echo "Please specify which module to load using 'zgen prezto <name of module>'"
			return 1
		fi
		-zgen-prezto-load "'$module'"

	# this is a prezto option
	else
		shift
		if [[ ${file} =~ "^(:|:?prezto|:?module)" ]]; then
			echo "Please name only the modules name"
		fi
		-zgen-prezto-option ${file} "$*"
	fi

}

zgen() {
    local cmd="${1}"
    if [[ -z "${cmd}" ]]; then
        echo "usage: zgen [clone|completions|list|load|oh-my-zsh|prezto|reset|save|selfupdate|update]"
        return 1
    fi

    shift

    if functions "zgen-${cmd}" > /dev/null ; then
        "zgen-${cmd}" "${@}"
    else
        echo "zgen: command not found: ${cmd}"
    fi
}

zgen-init
fpath=($ZGEN_SOURCE $fpath)

autoload -U compinit
compinit -d "${ZGEN_DIR}/zcompdump"
