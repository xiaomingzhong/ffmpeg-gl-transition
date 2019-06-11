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

function build_input(){
	for f in $1
	do
    	  echo " -i "${f}" "
	done
}

function build_map(){
	echo " -map \"[$1]\" "
}


function build_filter_args(){
	file_list=$1
	# audio list 
	flag=0
	for f in ${file_list}
	do
	  video_second=$(get_video_second ${f})
	  split_second=$[${video_second} - ${transition_time}]
      echo " [${flag}:a]atrim=0:${split_second}["a"${flag}]; "
 	  flag=$[${flag} + 1]
	done

	# video list 
	flag=0
	for f in ${file_list}
	do
    	  echo " [${flag}:v]split["vf"${flag}]["vb"${flag}]; "
	  flag=$[${flag} + 1]
	done

	# split video fragment 
	flag=0
	for f in ${file_list}
	do
	  video_second=$(get_video_second ${f})
	  split_second=$[${video_second} - ${transition_time}]
      echo " ["vf"${flag}]trim=0:${split_second}["vff"${flag}]; "
	  echo " ["vb"${flag}]trim=${split_second}:${video_second},setpts=PTS-STARTPTS["vbb"${flag}]; "
	  flag=$[${flag} + 1]
	done

	# concat gltransition video 
	flag=0
	size=${#video_list[@]}
	last_flag=$[${size} - 1]
	for ((i=0;i<last_flag;i++))
	{
      behind=$[${flag} + 1]
	  gl_len=${#gltransition_list[@]}
	  rdm=$(random_number ${gl_len})
	  gltransition_name=${gltransition_list[${rdm}]}
		  
      echo " ["vbb"${flag}]["vff"${behind}]gltransition=duration=${transition_time}:source=${transition_path}/${gltransition_name}["gl"${flag}]; "
	  flag=$[${flag} + 1]
    }
	
	# concat all video fragment
	flag=0
	all_fragment="["vff"${flag}]"
	vsize=0
	vsize=$[${vsize} + 1]
	
	for ((i=0;i<last_flag;i++))
	{
	  all_fragment=${all_fragment}"["gl"${flag}]"
	  flag=$[${flag} + 1]
	  vsize=$[${vsize} + 1]
    }
	
	all_fragment=${all_fragment}"["vbb"${flag}]"
	vsize=$[${vsize} + 1]
	
	echo ${all_fragment}"concat=n=${vsize} [v]; "

	# concat all audio fragment
	flag=0
	all_fragment=
	for f in ${file_list}
	do
	  all_fragment=${all_fragment}"["a"${flag}]"
 	  flag=$[${flag} + 1]
	done
    echo ${all_fragment}"concat=n=${flag}:v=0:a=1[audio] "
}

function ffmpeg_build(){
	echo `ffmpeg  "$(build_filter_args $1)"`
}


transition_time=3 # 3s
transition_path=/home/xiaoming/Downloads/youtube/30s/transitions
video_path=/home/xiaoming/Downloads/youtube/30s/source
gltransition_name=
out_video_name="out.mp4"
gltransition_list=()
video_list=()

# *******************load glsl files*******************************
	index=0
	for f in ${transition_path}/*
	do
	  gltransition_list[index]=$(basename ${f})
	  index=$[${index} + 1]
	done
# *****************************************************************

# *******************load video files*******************************
	index=0
	for f in ${video_path}/*.mp4
	do
	  video_list[index]=${f}
	  index=$[${index} + 1]
	done
# *****************************************************************

input=$(build_input "${video_list[*]}")

filter_complex=" -filter_complex "

filter_args=$(build_filter_args "${video_list[*]}")

map_v=$(build_map "v")
map_audio=$(build_map "audio")

# vcodec_arg=" -vcodec libx264 -crf 23 -preset medium -acodec aac -strict experimental -ac 2 -y ${out_video_name}"
vcodec_arg=" -vcodec libx264 -strict experimental -y ${out_video_name}"

echo "ffmpeg"${input}${filter_complex}"\""${filter_args}"\""${map_v}${map_audio}${vcodec_arg}
