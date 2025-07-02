display notification "알림이 성공적으로 작동합니다." with title "📣 Minari 앱"
repeat
	-- 🧭 실행할 기능 선택
	set actionList to {"📁 JPG 정리", "🖍️ 태그식 셀렉", "🗑️ 삭제식 셀렉", "🧹 확장자 정리", "📦 구글 드라이브 백업", "📤 하위 폴더 정리"}
	set userChoice to choose from list actionList with prompt "실행할 작업을 선택하세요:" with title "MINARI 자동화 런처"
	if userChoice is false then exit repeat
	set selected to item 1 of userChoice

	-- 📁 JPG 정리: 현재 폴더에서 .jpg/.JPG 파일을 "JPG" 폴더로 이동
	if selected is "📁 JPG 정리" then
		set folderPath to POSIX path of (choose folder with prompt "📂 JPG를 정리할 폴더 선택:")
		
		-- JPG 폴더 생성 및 이동
		do shell script "cd " & quoted form of folderPath & " && mkdir -p JPG && find . -maxdepth 1 -type f \( -iname '*.JPG' -o -iname '*.jpg' \) -exec mv {} JPG/ \;"
		
		-- ✅ 알림 (직접 표시)
		display notification "JPG 정리가 완료되었습니다." with title "✅ 정리 완료"
	end if
	
	-- 🖍️ 태그식 셀렉 (배치 최적화 + 직접 알림 표시 + 오류 대응)
	if selected is "🖍️ 태그식 셀렉" then
		set jpgFolder to choose folder with prompt "📂 JPG 폴더를 선택하세요:"
		set rawFolder to choose folder with prompt "📂 RAW 폴더를 선택하세요:"
		set jpgPath to POSIX path of jpgFolder
		set rawPath to POSIX path of rawFolder
		set rawExtensions to {"ARW", "CR2", "NEF", "RAF", "ORF"}

		-- 1. JPG 목록 전체 스캔
		set jpgList to paragraphs of (do shell script "find " & quoted form of jpgPath & " -type f -iname '*.jpg' -exec basename {} \;")
		set taggedList to {}

		-- 2. 태그 있는 파일만 추출
		repeat with fileName in jpgList
			set fullPath to jpgPath & fileName
			set hasTag to do shell script "xattr -p com.apple.metadata:_kMDItemUserTags " & quoted form of fullPath & " >/dev/null 2>&1 && echo yes || echo no"
			if hasTag is "yes" then
				copy fileName to end of taggedList
			end if
		end repeat

		set totalCount to count of taggedList
		if totalCount = 0 then
			display notification "태그된 JPG가 없습니다." with title "⚠️ 작업 중단"
			return
		end if

		display notification "총 " & totalCount & "개 RAW 복사 시작" with title "📄 태그식 셀렉 진행 중"
		set processedCount to 0
		set lastPercentShown to 0
		set startTime to (do shell script "date +%s") as integer

		-- 3. RAW 일괄 복사
		repeat with fileName in taggedList
			set baseName to text 1 thru -5 of fileName
			repeat with ext in rawExtensions
				set rawFile to rawPath & baseName & "." & ext
				set fileExists to do shell script "[ -f " & quoted form of rawFile & " ] && echo yes || echo no"
				if fileExists is "yes" then
					do shell script "cp " & quoted form of rawFile & " " & quoted form of jpgPath
					set processedCount to processedCount + 1
					exit repeat
				end if
			end repeat
			-- 퍼센트 단위 알림 (1초 간격)
			set currentPercent to round ((processedCount / totalCount) * 100)
			set nowTime to (do shell script "date +%s") as integer
			if currentPercent ≥ (lastPercentShown + 1) and currentPercent < 100 and (nowTime - startTime) ≥ 1 then
				display notification "진행률: " & currentPercent & "% (" & processedCount & "/" & totalCount & ")" with title "📄 RAW 복사 진행 중"
				set lastPercentShown to currentPercent
				set startTime to nowTime
			end if

			-- 100% 도달 즉시 알림
			if processedCount = totalCount and currentPercent = 100 and lastPercentShown < 100 then
				display notification "RAW 복사 100% 완료!" with title "📄 태그식 셀렉"
				set lastPercentShown to 100
			end if
		end repeat

		-- 4. 태그 일괄 제거
		repeat with fileName in taggedList
			set fullPath to jpgPath & fileName
			do shell script "xattr -d com.apple.metadata:_kMDItemUserTags " & quoted form of fullPath & " 2>/dev/null"
			do shell script "xattr -d com.apple.FinderInfo " & quoted form of fullPath & " 2>/dev/null"
		end repeat

		-- 5. 모든 JPG를 RAW 폴더로 이동
		do shell script "find " & quoted form of jpgPath & " -type f -iname '*.jpg' -exec mv {} " & quoted form of rawPath & " \;"
		display notification "태그식 셀렉 완료됨. 총 " & processedCount & "개 파일 처리됨" with title "✅ 완료"
	end if
	-- 🗑️ 삭제식 셀렉: JPG 기준 RAW 복사 후 JPG 삭제 + 퍼센트 알림
	if selected is "🗑️ 삭제식 셀렉" then
		set jpgFolder to choose folder with prompt "📂 JPG 폴더를 선택하세요:"
		set rawFolder to choose folder with prompt "📂 메인 폴더(=RAW가 있는 폴더)를 선택하세요:"
		
		set jpgPath to POSIX path of jpgFolder
		set rawPath to POSIX path of rawFolder
		set rawExtensions to {"ARW", "CR2", "NEF", "RAF", "ORF"}

		-- JPG 목록 확보
		set jpgList to paragraphs of (do shell script "find " & quoted form of jpgPath & " -type f -iname '*.jpg' -exec basename {} \;")
		set totalCount to count of jpgList
		if totalCount = 0 then
			display notification "JPG 파일이 없습니다." with title "⚠️ 작업 중단"
			return
		end if
		display notification "총 " & totalCount & "개 RAW 복사 시작" with title "🗑️ 삭제식 셀렉 진행 중"

		set processedCount to 0
		set lastPercentShown to 0
		set startTime to (do shell script "date +%s") as integer

		-- RAW 복사 & JPG 삭제
		repeat with fileName in jpgList
			set baseName to text 1 thru -5 of fileName

			repeat with ext in rawExtensions
				set rawFilePath to rawPath & baseName & "." & ext
				set fileExists to do shell script "[ -f " & quoted form of rawFilePath & " ] && echo yes || echo no"
				if fileExists is "yes" then
					do shell script "cp " & quoted form of rawFilePath & " " & quoted form of jpgPath
					do shell script "rm -f " & quoted form of (jpgPath & fileName)
					set processedCount to processedCount + 1
					exit repeat
				end if
			end repeat

			-- 퍼센트 단위 알림 (1초 간격, 99%까지)
			set currentPercent to round ((processedCount / totalCount) * 100)
			set nowTime to (do shell script "date +%s") as integer
			if currentPercent ≥ lastPercentShown + 1 and currentPercent < 100 and (nowTime - startTime) ≥ 1 then
				display notification "진행률: " & currentPercent & "% (" & processedCount & "/" & totalCount & ")" with title "🗑️ RAW 복사 진행 중"
				set lastPercentShown to currentPercent
				set startTime to nowTime
			end if

			-- 100% 도달 즉시 알림
			if processedCount = totalCount and currentPercent = 100 and lastPercentShown < 100 then
				display notification "RAW 복사 100% 완료!" with title "🗑️ 삭제식 셀렉"
				set lastPercentShown to 100
			end if
		end repeat

		-- 완료 알림
		display notification "삭제식 셀렉 완료됨. 총 " & processedCount & "개 RAW 복사 및 JPG 삭제됨" with title "✅ 완료"
	end if
	-- 🧹 확장자 정리: 같은 확장자별로 폴더를 생성하고 정리
	if selected is "🧹 확장자 정리" then
		set folderPath to POSIX path of (choose folder with prompt "📂 정리할 폴더 선택:")
		-- 폴더 내 확장자 목록 가져오기
		set extList to do shell script "\
		cd " & quoted form of folderPath & " && \
		find . -maxdepth 1 -type f | sed 's/.*\\.'//' | sort | uniq"
		set extArray to paragraphs of extList
		
		repeat with ext in extArray
			-- 확장자별 파일 개수 확인 후, 존재하면 폴더 생성 및 이동
			set countResult to do shell script "\
			cd " & quoted form of folderPath & " && \
			ls -1 *." & ext & " 2>/dev/null | wc -l"
			if countResult is not "0" then
				do shell script "\
			cd " & quoted form of folderPath & " && \
			mkdir -p " & ext & " && \
			find . -maxdepth 1 -type f -iname '*." & ext & "' -exec mv {} " & ext & "/ \;"
			end if
		end repeat
		display notification "확장자별 정리가 완료되었습니다." with title "✅ 정리 완료"
	end if
	
	-- 📦 구글 드라이브 백업: 각 세션의 Output 폴더를 Google Drive에 복사
	if selected is "📦 구글 드라이브 백업" then
		set projectFolder to POSIX path of (choose folder with prompt "📂 프로젝트 폴더 선택:")
		set googleFolder to POSIX path of (choose folder with prompt "📂 구글 드라이브 백업 폴더 선택:")
		
		-- 1단계: 프로젝트 폴더 내부 1단계 세션 폴더 나열
		set sessionList to paragraphs of (do shell script "find " & quoted form of projectFolder & " -type d -depth 1")
		repeat with sessionPath in sessionList
			set outputFolder to sessionPath & "/Output/"
			set sessionName to do shell script "basename " & quoted form of sessionPath
			set backupTarget to googleFolder & sessionName & "_Output/"
			
			-- Output 폴더 존재 및 내용 확인 → 복사
			set hasFiles to do shell script "find " & quoted form of outputFolder & " -type f 2>/dev/null | wc -l"
			if hasFiles is not "0" then
				do shell script "mkdir -p " & quoted form of backupTarget
				do shell script "cp -R " & quoted form of outputFolder & "* " & quoted form of backupTarget
			end if
		end repeat
		
		display notification "Output 폴더 백업이 완료되었습니다." with title "✅ 백업 완료"
	end if
	-- 📤 하위 폴더 정리 기능: 하위 폴더의 모든 파일을 상위로 이동하고 컬러 태그 제거
	if selected is "📤 하위 폴더 정리" then
		set baseFolder to POSIX path of (choose folder with prompt "📂 정리할 상위 폴더를 선택하세요:")
		
		-- 하위 폴더 내부 모든 파일을 상위 폴더로 이동 (중복시 덮어쓰기)
		do shell script "find " & quoted form of baseFolder & " -mindepth 2 -type f -exec mv -f {} " & quoted form of baseFolder & " \;"
		
		-- 하위 폴더 전부 삭제
		do shell script "find " & quoted form of baseFolder & " -mindepth 1 -type d -exec rm -rf {} +"
		
		-- 모든 컬러 태그 (회색 포함) 제거
		do shell script "find " & quoted form of baseFolder & " -type f -exec xattr -d com.apple.metadata:_kMDItemUserTags {} \; 2>/dev/null"
		do shell script "find " & quoted form of baseFolder & " -type f -exec xattr -d com.apple.FinderInfo {} \; 2>/dev/null"

		-- 완료 알림 표시
		do shell script "osascript -e 'display notification \"정리 및 모든 컬러 태그 제거 완료\" with title \"📤 완료\"'"
	end if
end repeat
