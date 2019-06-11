#!/bin/bash

function random_number(){
	random=$(( (RANDOM % $1) ))
    echo -n "$random"
}
function get_video_format_time(){
	echo `ffmpeg -i $1 2>&1 | grep 'Duration' | cut -d ' ' -f 4 | sed s/,//` # 00:02:39.04
}

function get_video_second(){
	ft=$(get_video_format_time $1) 
	list=(${ft//:/ }) # 00:02:39.04 ==> [00,02,39.04]
	h=${list[0]}
	m=${list[1]}
	s=${list[2]%.*}  # 39.04 ==> 39
	echo $[${h}*3600 + ${m}*60 + s ]  # 00 * 02 * 39
}

function build_complex(){
	file_list=$1
	flen=${#file_list[@]}
	
	for f in $file_list
	do
    	  echo " -i "${f}" "
	done

	echo " -filter_complex \" "

	# audio list 
	flag=0
	for f in $file_list
	do
	  video_second=$(get_video_second ${f})
	  split_second=$[${video_second} - ${transition_time}]
      echo " [${flag}:a]atrim=0:${split_second}["a"${flag}]; "
 	  flag=$[${flag} + 1]
	done

	# video list 
	flag=0
	for f in $file_list
	do
    	  echo " [${flag}:v]split["vf"${flag}]["vb"${flag}]; "
	  flag=$[${flag} + 1]
	done

	# split video fragment 
	flag=0
	for f in $file_list
	do
	  video_second=$(get_video_second ${f})
	  split_second=$[${video_second} - ${transition_time}]
      echo " ["vf"${flag}]trim=0:${split_second}["vff"${flag}]; "
	  echo " ["vb"${flag}]trim=${split_second}:${video_second},setpts=PTS-STARTPTS["vbb"${flag}]; "
	  flag=$[${flag} + 1]
	done

	# concat gltransition video 
	flag=0
	for f in $file_list
	do
	  	if [ $[${flag}] -le $[${flen}] ]; then # flag < flen
          behind=$[${flag} + 1]
		  
		  gl_len=${#gltransition_list[@]}
		  rdm=$(random_number ${gl_len})
		  gltransition_name=${gltransition_list[${rdm}]}
		  
    	  echo " ["vbb"${flag}]["vff"${behind}]gltransition=duration=${transition_time}:source=${transition_path}/${gltransition_name}["gl"${flag}]; "
	      flag=$[${flag} + 1]
      	fi 
	done 
	
	# concat all video fragment
	flag=0
	size=0
	all_fragment=
	for f in $file_list
	do
	  	if [ $[${flag}] == '0' ]; then  # flag < flen
          all_fragment="["vff"${flag}]"
		  all_fragment=${all_fragment}"["gl"${flag}]"
		  flag=$[${flag} + 1]
		  size=$[${size} + 2]
		elif [ $[${flag}] -le $[${flen}] ]; then  
    	  all_fragment=${all_fragment}"["gl"${flag}]"
	      flag=$[${flag} + 1]
		  size=$[${size} + 1]
		else 
		  all_fragment=${all_fragment}"["vbb"${flag}]"
		  flag=$[${flag} + 1]
		  size=$[${size} + 1]
      	fi 
	done 
	echo ${all_fragment}"concat=n=${size} [v]; "

	# concat all audio fragment
	flag=0
	all_fragment=
	for f in $file_list
	do
	  all_fragment=${all_fragment}"["a"${flag}]"
 	  flag=$[${flag} + 1]
	done
    echo ${all_fragment}"concat=n=${flag}:v=0:a=1[audio] \""
	echo " -map \"[v]\" -map \"[audio]\" "
	echo " -vcodec libx264 -crf 23 -preset medium -acodec aac -strict experimental -ac 2 -y ${out_video_name}"
}

function ffmpeg_build(){
	echo `ffmpeg  "$(build_complex $1)"`
}


transition_time=2 # 3s
transition_path=/home/xiaoming/Downloads/youtube/30s/transitions
gltransition_name=
out_video_name="out.mp4"
gltransition_list=()

# *******************load glsl files*******************************
	index=0
	for f in ${transition_path}/*
	do
	  gltransition_list[index]=$(basename ${f})
	  index=$[${index} + 1]
	done
# *****************************************************************

paths=("/home/xiaoming/Downloads/youtube/30s/1.mp4" "/home/xiaoming/Downloads/youtube/30s/2.mp4" "/home/xiaoming/Downloads/youtube/30s/0.mp4")
ffmpeg_args=$(build_complex "${paths[*]}")

echo "ffmpeg"${ffmpeg_args}




