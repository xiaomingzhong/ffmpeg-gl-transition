#!/bin/bash

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

function ffmpeg_build(){
ffmpeg -i 0.mp4 -i 1.mp4 -i 2.mp4   \
-filter_complex \
" [0:a]atrim=0:14[audio0]; [1:a]atrim=0:14[audio1]; [2:a]atrim=0:13[audio2]; \
  [0:v]split[v0][v10]; [1:v]split[v20][v30]; [2:v]split[v40][v50]; \
[v0]trim=0:13[v1];  \
[v10]trim=13:15,setpts=PTS-STARTPTS[v11];  \
[v20]trim=0:13[v21];  \
[v30]trim=13:15,setpts=PTS-STARTPTS[v31];  \
[v40]trim=0:13[v41]; \
[v50]trim=13:15,setpts=PTS-STARTPTS[v51];  \
[v11][v21]gltransition=duration=1:source=./transitions/CircleCrop.glsl[vt0]; \
[v31][v41]gltransition=duration=1:source=./transitions/CircleCrop.glsl[vt1];  \
[v1][vt0][vt1][v51]concat=n=4 [v];  \
[audio0][audio1][audio2]concat=n=3:v=0:a=1[audio]" -map "[v]" -map "[audio]" \
-vcodec libx264 -crf 23 -preset medium -acodec aac -strict experimental -ac 2 -y out.mp4
}


function build_complex(){
	file_list=$1
	flen=${#file_list[@]}
	
	for f in $file_list
	do
    	  echo " -i "${f}
	done

	echo " -filter_complex \""

	# audio list 
	flag=0
	for f in $file_list
	do
	  video_second=$(get_video_second ${f})
	  split_second=$[${video_second} - 3]
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
	  split_second=$[${video_second} - 3]
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
    	  echo " ["vbb"${flag}]["vff"${behind}]gltransition=duration=3:source=./transitions/CircleCrop.glsl["gl"${flag}]; "
	      flag=$[${flag} + 1]
      	fi 
	done 
	
	# concat all video fragment
	flag=0
	all_fragment=
	for f in $file_list
	do
	  	if [ $[${flag}] == '0' ]; then # flag < flen
          all_fragment="["vff"${flag}]"
		  flag=$[${flag} + 1]
		elif $[${flag}] -le $[${flen}]; then 
    	  all_fragment=${all_fragment}"["gl"${flag}]"
	      flag=$[${flag} + 1]
		else 
		  all_fragment=${all_fragment}"["vff"${flag}]"
		  flag=$[${flag} + 1]
      	fi 
	done 
	echo ${all_fragment}"concat=n=${flag} [v];"
	# [v1][vt0][vt1][v51]concat=n=4 [v];  \
# [audio0][audio1][audio2]concat=n=3:v=0:a=1[audio]" -map "[v]" -map "[audio]" \

}


second=$(get_video_second "/home/xiaoming/Downloads/youtube/30s/huzzah.mp4")

paths=("/home/xiaoming/Downloads/youtube/30s/huzzah.mp4" "/home/xiaoming/Downloads/youtube/30s/50_60s.mkv" "/home/xiaoming/Downloads/youtube/30s/0_10s.mp4")
bc=$(build_complex "${paths[*]}")


echo $second
echo ${bc}



