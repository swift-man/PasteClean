//
//  MessyPaste.swift
//  PasteClean
//
//  Created by 김승진 on 2026. 8. 19.
//
//  Extension 테스트용 샘플입니다. 어떤 타깃에도 포함되어 있지 않습니다.
//
//  회색 Xcode에서 이 파일을 열고 아래 블록을 선택한 뒤
//  Editor ▸ PasteClean ▸ Clean Pasted Code 를 실행해 보세요.
//

import Foundation

// ── 1. 한 줄 걸러 빈 줄이 들어간 경우 + continuation 정렬 ──

func layoutBanner() {

    make.left.right.equalToSuperview().inset(22)

    // 1000 : 313 비율

    make.height.equalTo(bannerView.snp.width)

      .multipliedBy(313.0 / 1000.0)

    make.bottom.equalToSuperview().offset(-20)

}

// ── 2. 줄 끝 공백 (아래 세 줄 끝에 공백이 있습니다) ──

let title = "Hello"   
let subtitle = "World"	
let footnote = "!"  

// ── 3. 중첩된 들여쓰기 (프로젝트 들여쓰기 폭에 맞춰집니다) ──

func process(_ items: [Int]) -> [Int] {

    var result: [Int] = []

    for item in items {

        if item > 0 {

            result.append(item * 2)

        }

    }

    return result

}

// ── 4. 의도한 빈 줄은 살아남고, 3줄 연속은 1줄로 줄어듭니다 ──

let first = 1
let second = 2



let third = 3

// ── 5. 여러 줄 문자열 안쪽은 건드리지 않습니다 ──

let query = """

    SELECT *

    FROM users

    """
