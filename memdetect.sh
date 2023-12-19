#!/bin/bash

COL="\e[34m"

COLB="\e[1;34m"

GREENB="\e[1;32m"

ERR="\e[1;31m"

WARN="\e[1;33m"

FAINT="\e[2;37m"

DEF="\e[0m"

ARGS=("$@")

ARGS_LEN=${#ARGS[@]}

EXTENSION=c

COMPILER=gcc

OPTIONS=("-fl" "--flags" "-fail" "-d" "-dir" "--directory" "-f" "--files" "-e"   \
"--exclude" "-ie" "--include-external" "-il" "--include-libs" "--output"  \
"-fo" "--filter-out" "-fi" "--filter-in" "-lb" "-leaks-buff" "-p" "--preserve" \
"-nr" "--no-report" "-s" "--show-calls" "-a" "--args" "-h" "--help" "--add-path" \
"-ix" "--include-xmalloc" "-u" "--update" "-+" "-++" "-cl" "--clean" \
"-n" "--dry-run" "-m" "--make-rule" "-v" "--verbose")

RE='^[0-9]+$'

EXCLUDE_FIND=""

EXCLUDE_RES=""

GCC_FLAGS=""

OUT_ARGS=""

LINK_STEP=""

MAKEFILE_RETRY=0

INCL_LIB=0

VERBOSE=0

ADDR_SIZE=10000

ONLY_SOURCE=1

MEMDETECT_OUTPUT="malloc_debug"

MAKE_RULE=""

MALLOC_FAIL_INDEX=0

AS_COMM=""

AS_FUNC=""

ONLY_REPORT="// "

AS_OG="og_"

INCL_XMALL="&& !strstr(stack[2], \"xmalloc\") && !strstr(stack[1], \"xmalloc\") && !strstr(stack[2], \"xrealloc\") && !strstr(stack[1], \"xrealloc\")"
SRC=""

HELP_MSG='
Usage:

./memdetect.sh { [ directory_paths | files ] } [compiler_flags] [memdetect options]

Description:
	files or directory paths:
		Only one of these types can be specified.
		If you insert a directory path, every .c or .cpp file
		inside the directory is gonna be compiled.
		To exclude one or more sub-folders use the -e option.
		If you dont insert this parameter,
		the script will use the Makefile tools,
		see Makefile intergration at README.md. This is the 
		only positional argument.

	compiler_flags:
		All the options or flags which need to be passed to
		the gcc or g++ compiler.
		They can be specified as flag1 flag2 ... flagN.
		Ex: -I include -g -O3

	memdetect options:
		See Options at README.md for list.
		They can be specified as option1 option1_arg option2 ... optionN.
		Ex: -a argument -nr -e example

All the arguments are optional.

Memdetect runs standard in C mode, to enable C++ mode use the -++ option.

Useful options:
	-a | --args arg1 arg2 ... argN:
		Use this option to feed arguments (char **argv) to the executable

	-s | --show-calls:
		Output data about every malloc or free call at runtime

	-v | --verbose:
		Show commands executed for compilation and running

	-fail N:
		Using this option will cause the Nth malloc
		call to fail (return 0)

	-+ | -++:
		Use to run in C++ mode

	-nr | --no-report:
		Display no report

	-fo | --filter-out func1 func2 .. funcN:
		Prevents specified functions from creating memdetect output

	-fi | --filter-in func1 func2 .. funcN:
		Prevents any not specified function from creating memdetect output

	-u | --update:
		Only works if memdetect is installed, updates the installed 
		executable to the latest commit from github

More flags and documentation at:
https://github.com/XEDGit/memdetect/blob/master/README.md
'

function error()
{
	printf "${ERR}Error: $1${DEF}\n"

	cleanup

	exit 1
}

function warning()
{
	printf "${WARN}Warning: $1${DEF}\n"
}

function printcol()
{
	[[ $VERBOSE -eq 0 ]] && [ "$DRY_RUN" != "y" ] && return 0

	[ -z "$2" ] && printf "${COL}$1${DEF}\n" || printf "${COLB}$1${DEF}\n"

	return 0
}

function cleanup()
{
	if [ -t 0 ]
	then
		while read -rs -t 0
		do
			read -rsn1

		done
	
	fi

	[ "$DRY_RUN" = "y" ] && exit 0

	[ -z "$PRESERVE" ] && rm -f "./fake_malloc.c"

	[ -z "$PRESERVE" ] && rm -f "./fake_malloc.o"

	[ -z "$PRESERVE" ] && rm -f "./fake_malloc_destructor.c"

	[ -z "$PRESERVE" ] && rm -f "./fake_malloc.dylib"

	[ -z "$PRESERVE" ] && rm -f "./$MEMDETECT_OUTPUT"

	[ -z "$PRESERVE" ] && rm -f "./memdtc_Makefile.tmp"

	return 0
}

function makefile_v1()
{
	printcol "Approach 'manual':"

	TMP_FILES=0

	MAKEFILE_DEPTH=0

	CMDS_LEN=${#MAKEFILE_CMDS[@]}

	i=0

	while [[ $i -lt $CMDS_LEN ]]
	do
		if [[ "${MAKEFILE_CMDS[$i]}" == "GNU Make "* ]]
		then
			if [[ $i -gt 0 ]]
			then
				MAKEFILE_CMDS=("${MAKEFILE_CMDS[@]:0:$i-1}" "${MAKEFILE_CMDS[@]:$i+6}")

			else
				MAKEFILE_CMDS=("${MAKEFILE_CMDS[@]:$i+6}")
				(( i-- ))

			fi
			(( CMDS_LEN = CMDS_LEN - 6 ))

		elif [[ "${MAKEFILE_CMDS[$i]}" == *"child"*"PID"* ]]
		then
			if [ "${MAKEFILE_CMDS[$i]:0:4}" = "Reap" ]
			then
				(( MAKEFILE_DEPTH-- ))
				MAKEFILE_CMDS=("${MAKEFILE_CMDS[@]:0:$i}" "popd" "${MAKEFILE_CMDS[@]:$i}")
				(( i++ ))
				(( CMDS_LEN++ ))

			elif [ "${MAKEFILE_CMDS[$i]:0:4}" = "Live" ]
			then
				(( MAKEFILE_DEPTH++ ))
				MAKEFILE_CMDS=("${MAKEFILE_CMDS[@]:0:$i}" "pushd $MAKEFILE_TARGET" "${MAKEFILE_CMDS[@]:$i}")
				(( i++ ))
				(( CMDS_LEN++ ))

			fi
			MAKEFILE_CMDS=( "${MAKEFILE_CMDS[@]/${MAKEFILE_CMDS[$i]}}" )

		elif [ -n "$(echo ${MAKEFILE_CMDS[$i]} | grep -E '^(-|@|\+|.*/)?make.*')" ]
		then
			MAKEFILE_CMDS[$i]="$(echo ${MAKEFILE_CMDS[$i]} | sed -E 's/.*make/echo Making target/g')"
			MAKEFILE_TARGET="$(echo ${MAKEFILE_CMDS[$i]} | sed -E 's/.*-C //' | sed -E 's/ .*//')"
			! [[ "$MAKEFILE_TARGET" == *"/" ]] && MAKEFILE_TARGET="${MAKEFILE_TARGET}/"

		elif [ "$EXTENSION" = 'cpp' ] && [ "${MAKEFILE_CMDS[$i]:0:4}" = "c++ " ]
		then
			MAKEFILE_CMDS[$i]="${MAKEFILE_CMDS[$i]/c++/$COMPILER}"

		elif [ "$EXTENSION" = 'cpp' ] && [ "${MAKEFILE_CMDS[$i]:0:8}" = "clang++ " ]
		then
			MAKEFILE_CMDS[$i]="${MAKEFILE_CMDS[$i]/clang++/$COMPILER}"

		elif [ "${MAKEFILE_CMDS[$i]:0:3}" = "cc " ]
		then
			MAKEFILE_CMDS[$i]="${MAKEFILE_CMDS[$i]/cc/$COMPILER}"

		elif [ "${MAKEFILE_CMDS[$i]:0:6}" = "clang " ]
		then
			MAKEFILE_CMDS[$i]="${MAKEFILE_CMDS[$i]/clang/$COMPILER}"

		fi

		if [[ $i -ge 0 ]] && [[ "${MAKEFILE_CMDS[$i]}" == "$COMPILER"* ]]
		then
			LINK_STEP=$i

		fi

		(( i++ ))
	done

	if [[ "${MAKEFILE_CMDS[0]}" == *"Nothing to be done for"* ]] && [[ ${#MAKEFILE_CMDS[@]} -eq 1 ]]
	then
		if [[ $MAKEFILE_RETRY -eq 1 ]]
		then
			error "Makefile tools failed (try cleaning the project object files)"

		fi
		((MAKEFILE_RETRY++))
		warning "No output from 'make -n', trying to clean project"
		unset MAKEFILE_OUTPUT
		make clean 1>/dev/null 2>&1
		make fclean 1>/dev/null 2>&1
		catch_makefile v1
		return

	fi

	MAKEFILE_LINK_FILE="$(echo "${MAKEFILE_CMDS[$LINK_STEP]}" | sed -E 's/.*-o( )?//' | sed -E 's/ .*//')"

	MAKEFILE_CMDS[$LINK_STEP]+=" ./fake_malloc.o -o ./$MEMDETECT_OUTPUT -rdynamic"

	[[ "$OSTYPE" != "darwin"* ]] && MAKEFILE_CMDS[$LINK_STEP]+=" -ldl"

	return 0
}

function makefile_v2()
{
	printcol "Approach 'native':"

	for i in ${!MAKEFILE_CMDS[@]}
	do
		if [[ "${MAKEFILE_CMDS[$i]}" == "$COMPILER"* ]] || [[ "${MAKEFILE_CMDS[$i]}" == "clang"* ]] || [[ "${MAKEFILE_CMDS[$i]}" == "g++"* ]] || [[ "${MAKEFILE_CMDS[$i]}" == "c++"* ]] || [[ "${MAKEFILE_CMDS[$i]}" == "cc"* ]]
		then
			if [[ "${MAKEFILE_CMDS[$i]}" == "clang++"* ]] || [[ "${MAKEFILE_CMDS[$i]}" == "g++"* ]] || [[ "${MAKEFILE_CMDS[$i]}" == "c++"* ]] && [ "$EXTENSION" = "c" ]
			then
				printcol "C++ files detected, defaulting to -++ option"
				COMPILER="g++"
				EXTENSION="cpp"

			fi
			(( COMPILER_COUNT++ ))

		fi
	done

	return 0
}

function catch_makefile()
{

	PROJECT_PATH="."

	MAKEFILE_SUCCESS="y"

	[ "$MEMDETECT_MAKEFILE_NOTHINGS" != "again" ] && MEMDETECT_MAKEFILE_NOTHINGS="n"

	COMPILER_COUNT=0

	VER="$1"

	if [ -z "$MAKEFILE_OUTPUT" ]
	then
		! [ -f "./Makefile" ] && error "Makefile tools failed (./Makefile not found)"
		! [ -f "./memdtc_Makefile.tmp" ] && cat ./Makefile | sed -E 's#^\t(-|@|\+|.*/)?make#\t$(MAKE)#g' > ./memdtc_Makefile.tmp
		MAKEFILE_OUTPUT=$(make -f ./memdtc_Makefile.tmp --debug=j -n $MAKE_RULE)
		IFS=$'\n' read -r -d '' -a MAKEFILE_CMDS <<<"$MAKEFILE_OUTPUT"

	fi

	[ "$VER" = "v1" ] && makefile_v1 || makefile_v2

	[ "$MAKEFILE_FAIL" = "y" ] && [ "$LINK_STEP" = "" ] && error "Makefile tools failed (linker command not found in 'make -n${MAKE_RULE:+" "}$MAKE_RULE')${DEF}"

	return 0
}

function exec_makefile()
{
	MAKEFILE_FAIL="n"
	for cmd in "${MAKEFILE_CMDS[@]}"
	do
		[ -z "$cmd" ] && continue

		if [ "$(echo \"$cmd\" | grep -e "$COMPILER"'*' )" != "" ]
		then
			GCC_CMD="$cmd$GCC_FLAGS"
			printcol "$GCC_CMD"
			[ "$DRY_RUN" != "y" ] && bash -c "$GCC_CMD 2>&1"

		else
			[ "${cmd::4}" = "echo" ] && continue
			type $(echo $cmd | sed -E 's/[[:space:]].*//') 1>/dev/null 2>&1
			! [[ $? -eq 0 ]] && printcol "Skipped '$cmd' because it's not recognized as command" && continue
			printcol "$cmd"
			if [ "$DRY_RUN" != "y" ]
			then
				[[ $VERBOSE -eq 1 ]] && eval "$cmd" || eval "$cmd" 1>/dev/null 2>&1

			fi

		fi

		! [[ $? -eq 0 ]] && MAKEFILE_FAIL="y" && pushd -0 && dirs -c && printcol "Approach 'manual' failed." && break
	done

	if	[ "$MAKEFILE_FAIL" = "y" ]
	then
		catch_makefile v2
		if [[ $COMPILER_COUNT -gt 1 ]]
		then
			[[ $VERBOSE -eq 1 ]] && make -f ./memdtc_Makefile.tmp ${DRY_RUN:+"-n"} $MAKE_RULE || make -f ./memdtc_Makefile.tmp ${DRY_RUN:+"-n"} $MAKE_RULE 1>/dev/null 2>&1
			! [[ $? -eq 0 ]] && cleanup && exit 1
			rm -f "$MAKEFILE_LINK_FILE"

		fi
		printcol "${MAKEFILE_CMDS[$LINK_STEP]}"
		[ "$DRY_RUN" != "y" ] && bash -c "${MAKEFILE_CMDS[$LINK_STEP]}"

	fi

	! [[ $? -eq 0 ]] && [ "$DRY_RUN" != "y" ] && cleanup && exit 1

	return 0
}

function compile_fake_malloc()
{
	if [[ "$OSTYPE" == "darwin"* ]]
	then
		[ "$DRY_RUN" != "y" ] && gcc -shared -fPIC ./fake_malloc.c -o ./fake_malloc.dylib -DONLY_SOURCE="$ONLY_SOURCE" -DINCL_LIB="$INCL_LIB" -DADDR_ARR_SIZE="$ADDR_SIZE" -DMALLOC_FAIL_INDEX="$COUNTER"
		! [[ $? -eq 0 ]] && [ "$DRY_RUN" != "y" ] && cleanup && exit 1
		[ "$DRY_RUN" != "y" ] && gcc ./fake_malloc_destructor.c -c -o ./fake_malloc.o
		! [[ $? -eq 0 ]] && [ "$DRY_RUN" != "y" ] && cleanup && exit 1

	else
		[ "$DRY_RUN" != "y" ] && gcc "./fake_malloc.c" -c -o "./fake_malloc.o" -DINCL_LIB="$INCL_LIB" -DONLY_SOURCE="$ONLY_SOURCE" -DADDR_ARR_SIZE="$ADDR_SIZE" -DMALLOC_FAIL_INDEX="$COUNTER"
		! [[ $? -eq 0 ]] && [ "$DRY_RUN" != "y" ] && cleanup && exit 1

	fi
}

function compile_bin()
{
	if [ "$MAKEFILE_SUCCESS" = "y" ]
	then
		exec_makefile

	else
		GCC_CMD="$COMPILER $SRC ./fake_malloc.o -rdynamic -o ./$MEMDETECT_OUTPUT$GCC_FLAGS"
		[[ "$OSTYPE" != "darwin"* ]] && GCC_CMD+=" -ldl"
		printcol "$GCC_CMD"
		[ "$DRY_RUN" != "y" ] && bash -c "$GCC_CMD 2>&1"
		! [[ $? -eq 0 ]] && [ "$DRY_RUN" != "y" ] && cleanup && exit 1

	fi
}

function exec_bin()
{
	CMD=""

	[[ "$OSTYPE" == "darwin"* ]] && CMD="DYLD_INSERT_LIBRARIES=./fake_malloc.dylib "

	CMD+="./$MEMDETECT_OUTPUT$OUT_ARGS"

	printcol "${CMD}:" "B"

	[ "$DRY_RUN" != "y" ] && bash -c "$CMD" 2>&1

	! [[ $? -eq 0 ]] && [ -z "$MALLOC_FAIL_LOOP" ] && [ "$DRY_RUN" != "y" ] && cleanup && exit 1

	return 0
}

function ask_loop_continue()
{
	printf "____________________________________________\n\e[1mPress any key to run -fail %s or 'q' to quit:$DEF" "$COUNTER"

	read -srn1 CONTINUE

	while read -rs -t 0
	do
		read -rsn1

	done

	[ ! "$CONTINUE" = $'\n' ] && printf "\n"

	[ "$CONTINUE" = "q" ] && return 1

	return 0
}

function loop()
{
	(( COUNTER = COUNTER - 1 ))

	CONTINUE=""

	while [[ $COUNTER -ge 0 ]]
	do

		(( COUNTER = COUNTER + 1 ))

		ask_loop_continue || break

		compile_fake_malloc

		compile_bin

		exec_bin

	done
}

function run()
{

	compile_fake_malloc

	compile_bin

	exec_bin
}

function check_update()
{
	PATH_TO_BIN=$(which memdetect) || error 'memdetect not found in $PATH'

	printf "curl https://raw.githubusercontent.com/XEDGit/memdetect/master/memdetect.sh\n"

	[ "$DRY_RUN" != "y" ] && curl https://raw.githubusercontent.com/XEDGit/memdetect/master/memdetect.sh >tmp 2>/dev/null

	! [[ $? -eq 0 ]] && [ "$DRY_RUN" != "y" ] && error "failed to download update"

	DIFF=$(diff tmp $PATH_TO_BIN)

	if [ "$DIFF" != "" ]
	then
		chmod +x tmp
		if [ -w $(dirname $PATH_TO_BIN) ]
		then
			printf "mv tmp $PATH_TO_BIN\n"
			[ "$DRY_RUN" != "y" ] && mv tmp $PATH_TO_BIN && printcol "Updated memdetect!" "B"

		else
			printf "sudo mv tmp $PATH_TO_BIN\n"
			[ "$DRY_RUN" != "y" ] && sudo mv tmp $PATH_TO_BIN && printcol "Updated memdetect!"
			! [[ $? -eq 0 ]] && [ "$DRY_RUN" != "y" ] && rm -f tmp && error "failed gaining privileges"

		fi
		rm -f tmp
		exit 0

	else
		printf "No update found.\n"
		rm tmp

	fi
}

function add_to_path()
{
	PATH_ARR=$(echo "$PATH" | tr ':' '\n')

	CONT=0

	CONT2=0

	EXE_PATH="$0"

	[ -z "$EXE_PATH" ] && error "memdetect executable not found"

	printf "Executable which will be installed: %s\n" "$EXE_PATH"

	echo "In which directory do you want to install it?"

	for VAL in $PATH_ARR
	do
		printf "\t$CONT) $VAL\n"

		(( CONT = CONT + 1 ))

	done

	while true
	do
		printf "Select index (Ctrl + c to stop): "

		read -r PATH_CHOICE

		{ [[ ! ("$PATH_CHOICE" =~ $RE) ]] || [[ "$PATH_CHOICE" -lt 0 ]] || [[ "$PATH_CHOICE" -gt $((CONT - 1)) ]]; } && echo "Index not in range" && continue

		break

	done

	for VAL in $PATH_ARR
	do
		[[ $CONT2 -eq $PATH_CHOICE ]] && PATH_CHOICE=$VAL && break

		(( CONT2 = CONT2 + 1 ))

	done

	[ ! -e "$PATH_CHOICE" ] && error "'$PATH_CHOICE' directory doesn't exists"

	printf "${COL}Copying memdetect to $PATH_CHOICE${DEF}\n"

	if [ -w "$PATH_CHOICE" ]
	then
		printf "cp $EXE_PATH ${PATH_CHOICE%/}/memdetect\n"
		[ "$DRY_RUN" != "y" ] && cp $EXE_PATH "${PATH_CHOICE%/}"/memdetect

	else
		printf "sudo cp $EXE_PATH ${PATH_CHOICE%/}/memdetect\n"
		[ "$DRY_RUN" != "y" ] && sudo cp $EXE_PATH "${PATH_CHOICE%/}"/memdetect

	fi

	printf "${COLB}Success!${DEF}\n"
}

function check_options()
{
	for OPT in "${OPTIONS[@]}"
	do
		[ "$1" = "$OPT" ] && return 0

	done

	return 1
}

function check_dependencies()
{
	type make >/dev/null 2>&1 || error "make is not installed, exiting"
	type gcc >/dev/null 2>&1 || error "gcc is not installed, exiting"
}

! [ -t 1 ] && COL="" && COLB="" && DEF="" && FAINT="" && ERR="" && WARN=""

check_dependencies

I=0

if [[ $I -lt $ARGS_LEN ]] && ! check_options "${ARGS[$I]}"
then
	if [ -d "${ARGS[$I]}" ]
	then
		while [[ $I -lt $ARGS_LEN ]]
		do
			[[ ${ARGS[$I]} == "-"* ]] && break

			! [ -d "${ARGS[$I]}" ] && error "'${ARGS[$I]}' is not a directory"

			PROJECT_PATH+="${ARGS[$I]%/} "

			(( I = I + 1 ))

		done

	else
		while [[ $I -lt $ARGS_LEN ]]
		do
			[[ ${ARGS[$I]} == "-"* ]] && break

			PROJECT_PATH="."

			! [ -f "${ARGS[$I]}" ] && error "${ARGS[$I]} is not a file"

			FILE_PATH+=" ${ARGS[$I]}"

			(( I = I + 1 ))

		done

	fi

fi

while [[ $I -lt $ARGS_LEN ]]
do
    arg=${ARGS[$I]}

	case $arg in

        "-e" | "--exclude")
			check_options "${ARGS[$I + 1]}" && error "value '${ARGS[$I + 1]}' for ${ARGS[$I]} flag is a memdetect flag"

			(( I = I + 1 ))

			while [[ $I -lt $ARGS_LEN ]]
			do
				check_options "${ARGS[$I]}" && (( I = I - 1 )) && break

				EXCLUDE_FIND+="! -path '*${ARGS[$I]}*' "

				(( I = I + 1 ))

			done
        ;;

		"-fo" | "--filter-out")
			check_options "${ARGS[$I + 1]}" && error "value '${ARGS[$I + 1]}' for ${ARGS[$I]} option is a memdetect option"

			(( I = I + 1 ))

			II=0

			EXCLUDE_RES="&& ("

			while [[ $I -lt $ARGS_LEN ]]
			do
				check_options "${ARGS[$I]}" && (( I = I - 1 )) && break

				! [[ $II -eq  0 ]] && EXCLUDE_RES+=" &&"

				(( II = II + 1))

				EXCLUDE_RES+=" !strstr(stack[2], \"${ARGS[$I]}\") && !strstr(stack[3], \"${ARGS[$I]}\")"

				(( I = I + 1 ))

			done

			EXCLUDE_RES+=")"
		;;

		"-fi" | "--filter-in")
			check_options "${ARGS[$I + 1]}" && error "value '${ARGS[$I + 1]}' for ${ARGS[$I]} option is a memdetect option"

			(( I = I + 1 ))

			II=0

			EXCLUDE_RES="&& !("

			while [[ $I -lt $ARGS_LEN ]]
			do
				check_options "${ARGS[$I]}" && (( I = I - 1 )) && break

				! [[ $II -eq  0 ]] && EXCLUDE_RES+=" &&"

				(( II = II + 1))

				EXCLUDE_RES+=" !strstr(stack[2], \"${ARGS[$I]}\") && !strstr(stack[3], \"${ARGS[$I]}\")"

				(( I = I + 1 ))

			done

			EXCLUDE_RES+=")"
		;;

		"-ie" | "--include-ext")
			ONLY_SOURCE=0
		;;

		"-il" | "--include-lib")
			INCL_LIB=1
		;;

		"-ix" | "--include-xmalloc")
			INCL_XMALL=""
		;;

		"-p" | "--preserve")
			PRESERVE=1
		;;

		"-v" | "--verbose")
			VERBOSE=1
		;;

		"-cl" | "--clean")
			unset PRESERVE

			cleanup

			exit 0
		;;

		"-fail")
			check_options "${ARGS[$I + 1]}" && error "value '${ARGS[$I + 1]}' for ${ARGS[$I]} option is a memdetect option"

			NEW_VAL=${ARGS[$I + 1]}

			if ! [[ $NEW_VAL =~ $RE ]]
			then
				if [ "$NEW_VAL" = "loop" ]
				then
					MALLOC_FAIL_LOOP=1
					if [ -n "${ARGS[$I + 2]}" ] && ! check_options "${ARGS[$I + 2]}" && [[ ${ARGS[$I + 2]} =~ $RE ]]
					then
						COUNTER=${ARGS[$I + 2]}

					else
						COUNTER=1

					fi

				elif [ "$NEW_VAL" = "all" ]
				then
					MALLOC_FAIL_INDEX=-1

				else
					error "the value of --fail '$arg' is not a number, 'all' or 'loop'"

				fi

			else
				MALLOC_FAIL_INDEX=$NEW_VAL

			fi
		;;

		"-+" | "-++")
			EXTENSION=cpp

			COMPILER=g++
		;;

        "-fl" | "--flags")
			check_options "${ARGS[$I + 1]}" && error "value '${ARGS[$I + 1]}' for ${ARGS[$I]} option is a memdetect option"

			(( I = I + 1 ))

			while [[ $I -lt $ARGS_LEN ]]
			do
				check_options "${ARGS[$I]}" && (( I = I - 1 )) && break

				GCC_FLAGS+=" ${ARGS[$I]}"

				(( I = I + 1 ))

			done
		;;

		"-n" | "--dry-run")
			DRY_RUN="y"

			printcol "Executing dry run..." "B"
		;;

		"-m" | "--make-rule")
			check_options "${ARGS[$I + 1]}" && error "value '${ARGS[$I + 1]}' for ${ARGS[$I]} option is a memdetect option"

			(( I = I + 1 ))

			MAKE_RULE="${ARGS[$I]}"
		;;

		"-a" | "--args")
			check_options "${ARGS[$I + 1]}" && error "value '${ARGS[$I + 1]}' for ${ARGS[$I]} option is a memdetect option"

			(( I = I + 1 ))

			while [[ $I -lt $ARGS_LEN ]]
			do
				check_options "${ARGS[$I]}" && (( I = I - 1 )) && break

				OUT_ARGS+=" ${ARGS[$I]}"

				(( I = I + 1 ))

			done
		;;

		"-lb" | "--leaks-buff")
			NEW_VAL=${ARGS[$I + 1]}

			(! [[ $NEW_VAL =~ $RE ]] || check_options "$NEW_VAL") && error "the value of --leaks-buff '$NEW_VAL' is not a number"

			ADDR_SIZE=$NEW_VAL
		;;

		"-nr" | "--no-report")
			NO_REPORT="// "
		;;

		"-s" | "--show-calls")
			ONLY_REPORT=""
		;;

		"--output")
			check_options "${ARGS[$I + 1]}" && error "value '${ARGS[$I + 1]}' for ${ARGS[$I]} option is a memdetect option"

			(( I = I + 1 ))

			if [ -f "${ARGS[$I]}" ] && [ "$DRY_RUN" != "y" ]
			then
				printf "Overwrite existing file \"${ARGS[$I]}\"? [y/N]"
				read -rn1 OUTPUT_CHOICE
				if [ "$OUTPUT_CHOICE" = "y" ] || [ "$OUTPUT_CHOICE" = "Y" ]
				then
					printf "\n"
				 	[ "$DRY_RUN" != "y" ] && rm -f "${ARGS[$I]}"

				else
					printf "\nExiting\n"
					exit 1

				fi

			fi

			[ "$DRY_RUN" != "y" ] && touch "${ARGS[$I]}" || error "Failed creating output file"

			[ "$DRY_RUN" != "y" ] && printcol "Output file ready!"

			[ "$DRY_RUN" != "y" ] && exec 1>"${ARGS[$I]}"

			[ "$DRY_RUN" != "y" ] && exec 2>&1
		;;

        "-h" | "--help")
			printf "$HELP_MSG"

            exit
        ;;

		"-u" | "--update")
			printf "Checking for updates...\n"

			check_update

			exit
		;;

		"--add-path")
			add_to_path

			exit
		;;

		*)
			if ! [[ $arg == "-"* ]]
			then
				error "'$arg' is not a recognized flag"
			fi
			GCC_FLAGS+=" $arg"
		;;
    esac

    (( I = I + 1 ))

done

printf "${COLB}================= memdetect by XEDGit ==================${DEF}\n"

{ [ -z "$FILE_PATH" ] && [ -z "$PROJECT_PATH" ]; } && printcol "Info: Missing path to project or file list.\nFalling back to Makefile tools" && catch_makefile v1

if [[ "$OSTYPE" == "darwin"* ]]
then
	AS_COMM="//"
	AS_FUNC="fake_"
	AS_OG=""
	[ "$DRY_RUN" != "y" ] && echo "extern void __attribute__((destructor)) malloc_hook_report();
extern void __attribute__((constructor)) malloc_hook_pid_detect();" > ./fake_malloc_destructor.c

fi

[ "$DRY_RUN" != "y" ] && eval "cat << EOF > ./fake_malloc.c
#define _GNU_SOURCE
#include <dlfcn.h>
#include <execinfo.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>

#define COL \"$COL\"

#define COLB \"$COLB\"

#define GREENB \"$GREENB\"

#define WARN \"$WARN\"

#define FAINT \"$FAINT\"

#define DEF \"$DEF\"

#define ERR \"$ERR\"

typedef struct s_addr {
	void	*address;
	char	*function;
	int		bytes;
	int		index;
}	t_addr;

#ifdef __APPLE__
# define MAC_OS_SYSTEM 1
# define DYLD_INTERPOSE(_replacment,_replacee) \
   __attribute__((used)) static struct{ const void* replacment; const void* replacee; } _interpose_##_replacee \
            __attribute__ ((section (\"__DATA,__interpose\"))) = { (const void*)(unsigned long)&_replacment, (const void*)(unsigned long)&_replacee };
#else
# define MAC_OS_SYSTEM 0
#endif

${AS_COMM}static void		(*og_free)(void *);
${AS_COMM}static void		*(*og_malloc)(size_t);
static int 		free_count = 0;
static int		init_run = 0;
static int 		zero_free_count = 0;
static int		malloc_count = 0;
static int		addr_i = 0;
static int		addr_rep = 0;
static t_addr	addresses[ADDR_ARR_SIZE] = {0};
static pid_t	parent_pid = 0;

${NO_REPORT}void __attribute__((constructor)) malloc_hook_pid_detect();
${NO_REPORT}void __attribute__((destructor)) malloc_hook_report();

void malloc_hook_handle_signals(int sig)
{
	printf( ERR \"Received signal %s\n\" DEF, strsignal(sig));
	exit(1);
}

void malloc_hook_pid_detect()
{
	signal(SIGSEGV, malloc_hook_handle_signals);
	signal(SIGABRT, malloc_hook_handle_signals);
	signal(SIGBUS, malloc_hook_handle_signals);
	init_run = 1;
	if (!parent_pid)
		parent_pid = getpid();
	init_run = 0;
}

int	malloc_hook_check_content(unsigned char *str)
{
	while (*str && *str >= 32 && *str <= 126)
		str++;
	if (!*str)
		return (0);
	return (1);
}

void malloc_hook_report()
{
	int	tot_leaks;

	if (parent_pid != getpid())
		return ;
	tot_leaks = 0;
	init_run = 1;

	printf(COLB \"MEMDETECT REPORT:\" DEF \"\n\tMalloc calls: \" COL \"%d\" DEF \"\tFree calls: \" COL \"%d\" DEF \"\tFree calls to 0x0: \" COL \"%d\" DEF \"\n\", malloc_count, free_count, zero_free_count);
	if (addr_rep)
		addr_i = ADDR_ARR_SIZE - 1;
	for (int i = 0; i <= addr_i; i++)
	{
		if (addresses[i].address)
		{
			if (!malloc_hook_check_content((unsigned char *)addresses[i].address))
				printf(COLB \"%d)\" DEF \"\tFrom \" COL \"MALLOC %d %s\" DEF \" of size \" COL \"%d\" DEF \" at address \"COL \"%p\" DEF \"	Content: \" COL \"\\\"%s\\\"\n\" DEF, tot_leaks++, addresses[i].index, addresses[i].function, addresses[i].bytes, addresses[i].address, (char *)addresses[i].address);
			else
				printf(COLB \"%d)\" DEF \"\tFrom \" COL \"MALLOC %d %s\" DEF \" of size \" COL \"%d\" DEF \" at address \"COL \"%p	Content unavailable\n\" DEF, tot_leaks++, addresses[i].index, addresses[i].function, addresses[i].bytes, addresses[i].address);
			${AS_OG}free(addresses[i].function);
		}
	}
	if (tot_leaks)
		printf(ERR \"Total leaks: %d\n\", tot_leaks);
	else
		printf(GREENB \"No leaks detected!\n\" DEF);
	printf(WARN \"WARNING:\" DEF \" the leaks freed by exit() are still displayed in the report\n\");
}

${AS_COMM}int init_malloc_hook()
${AS_COMM}{
${AS_COMM}	signal(SIGSEGV, malloc_hook_handle_signals);
${AS_COMM}	signal(SIGABRT, malloc_hook_handle_signals);
${AS_COMM}	signal(SIGBUS, malloc_hook_handle_signals);
${AS_COMM}	og_malloc = dlsym(RTLD_NEXT, \"malloc\");
${AS_COMM}	og_free = dlsym(RTLD_NEXT, \"free\");

${AS_COMM}	if (!og_malloc || !og_free)
${AS_COMM}		exit(1);
${AS_COMM}	return (0);
${AS_COMM}}

int	malloc_hook_backtrace_readable(char ***stack_readable)
{
	void	*stack[10];
	int		stack_size;

	stack_size = backtrace(stack, 10);
	
	*stack_readable = backtrace_symbols(stack, stack_size);
	return (stack_size);
}

void	malloc_hook_string_edit(char *str)
{
	char	ch;
	char	*start;
	char	*temp;

	ch = ' ';
	start = str;
	temp = str;
	if (!MAC_OS_SYSTEM)
	{
		char *lib_p = 0;

		ch = '+';
		while (*str && *(str - 1) != '(')
			if (*str++ == '/')
				lib_p = str;
		if ($INCL_LIB)
		{
			while (*lib_p && *lib_p != '(')
				*start++ = *lib_p++;
			*start++ = ' ';
			*start++ = '/';
			*start++ = ' ';
			temp = start;
		}
	}
	else
	{
		if ($INCL_LIB)
		{
			str++;
			while (*str == ' ')
				str++;
			while (*str != ' ')
				*start++ = *str++;
			*start++ = ' ';
			*start++ = '/';
			*start++ = ' ';
		}
		str = &temp[59];
	}
	while (*str && *str != ch)
		*start++ = *str++;
	if (start == temp)
	{
		*start++ = '?';
		*start++ = '?';
	}
	*start = 0;
}

void	*${AS_FUNC}malloc(size_t size)
{
	void		*ret;
	char		**stack;
	int			stack_size;
	static int	malloc_fail = 0;

	${AS_COMM}if (!og_malloc)
	${AS_COMM}	if (init_malloc_hook())
	${AS_COMM}		exit (1);
	if (init_run)
		return (${AS_OG}malloc(size));
	init_run = 1;
	stack_size = malloc_hook_backtrace_readable(&stack);
	if (ONLY_SOURCE && stack_size > 4 && !(strstr(stack[2], \"${MEMDETECT_OUTPUT}\") || strstr(stack[3], \"${MEMDETECT_OUTPUT}\") || strstr(stack[4], \"${MEMDETECT_OUTPUT}\")))
	{
		${AS_OG}free(stack);
		init_run = 0;
		return (${AS_OG}malloc(size));
	}
	malloc_hook_string_edit(stack[2]);
	malloc_hook_string_edit(stack[3]);
	if (stack[2][0] != '?' $EXCLUDE_RES $INCL_XMALL)
	{
		malloc_count++;
		if (++malloc_fail == MALLOC_FAIL_INDEX || MALLOC_FAIL_INDEX == -1)
		{
			printf(COLB \"FAILED MALLOC:\t %s -> %s malloc number %d returned NULL (0)\" DEF \"\n\", stack[3], stack[2], malloc_fail);
			${AS_OG}free(stack);
			init_run = 0;
			return (0);
		}
		ret = ${AS_OG}malloc(size);
		addr_i++;
		if (addr_i == ADDR_ARR_SIZE)
		{
			addr_rep = 1;
			addr_i = 0;
		}
		while (addr_i < ADDR_ARR_SIZE - 1 && addresses[addr_i].address)
			addr_i++;
		if (addr_i == ADDR_ARR_SIZE - 1 && addresses[addr_i].address)
		{
			printf(ERR \"MEMDETECT ERROR:\t\" DEF \" Not enough buffer space, default is 10000 specify a bigger one with the --leaks-buff flag\n\");
			${AS_OG}free(stack);
			exit (1);
		}
		addresses[addr_i].function = strdup(stack[2]);
		addresses[addr_i].bytes = size;
		addresses[addr_i].index = malloc_count;
		addresses[addr_i].address = ret; 
		${ONLY_REPORT}printf(COLB \"MALLOC %d: \" FAINT \"%s -> %s allocated %zu bytes at %p\" DEF \"\n\", malloc_count, stack[3], stack[2], size, ret);
	}
	else
		ret = ${AS_OG}malloc(size);
	init_run = 0;
	${AS_OG}free(stack);
	return (ret);
}

void	${AS_FUNC}free(void *tofree)
{
	char	**stack;

	if (init_run)
	{
		${AS_OG}free(tofree);
		return ;
	}
	init_run = 1;
	int stack_size = malloc_hook_backtrace_readable(&stack);
	if (ONLY_SOURCE && stack_size > 4 && !(strstr(stack[2], \"${MEMDETECT_OUTPUT}\") || strstr(stack[3], \"${MEMDETECT_OUTPUT}\") || strstr(stack[4], \"${MEMDETECT_OUTPUT}\")))
	{
		${AS_OG}free(stack);
		init_run = 0;
		return ;
	}
	malloc_hook_string_edit(stack[2]);
	malloc_hook_string_edit(stack[3]);
	if (stack[2][0] != '?' $INCL_XMALL)
	{
		${ONLY_REPORT}if (1 $EXCLUDE_RES)
		${ONLY_REPORT}printf(COLB \"FREE:\t\" FAINT \" %s -> %s free %p\" DEF \"\n\" , stack[3], stack[2], tofree);
		if (tofree)
		{
			free_count++;
			for (int i=0; i <= addr_i; i++)
			{
				if (addresses[i].address == tofree)
				{
					${AS_OG}free(addresses[i].function);
					addresses[i].function = 0;
					addresses[i].bytes = 0;
					addresses[i].address = 0;
					addresses[i].index = 0;
				}
			}
		}
		else
		{
			zero_free_count++;
		}
	}
	init_run = 0;
	${AS_OG}free(stack);
	${AS_OG}free(tofree);
}

$([ -z "$AS_COMM" ] && echo "// ")DYLD_INTERPOSE(fake_malloc, malloc);
$([ -z "$AS_COMM" ] && echo "// ")DYLD_INTERPOSE(fake_free, free);

EOF"

if [ -z "$FILE_PATH" ]
then
	SRC+=$(eval "find $PROJECT_PATH -name '*.$EXTENSION' $EXCLUDE_FIND" | grep -v fake_malloc.c | tr '\n' ' ')

else
	SRC+="$FILE_PATH"

fi

if [ -z "$MALLOC_FAIL_LOOP" ]
then
	COUNTER=$MALLOC_FAIL_INDEX
	run

else
	loop
	printcol "\nExiting\n"

fi

cleanup

exit 0
