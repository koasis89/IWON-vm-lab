#!/usr/bin/env python3
"""
patch_jar_xml.py — Spring Boot JAR 내 XML 매퍼 파일에서
소문자 gpcl_ 테이블명 접두사를 대문자 GPCL_ 로 일괄 치환한다.

Linux MariaDB는 lower_case_table_names=0 (대소문자 구분) 이므로
테이블이 GPCL_* 대문자로 존재할 경우, MyBatis XML에서
소문자 gpcl_* 로 참조하면 "Table doesn't exist" 에러가 발생한다.

사용법:
  python3 patch_jar_xml.py --jar /opt/apps/was/app.jar
"""
import argparse
import os
import re
import shutil
import zipfile


# SQL 문법에서 identifier 로만 사용되는 패턴 (맞춤)
PATTERN = re.compile(r'gpcl_([a-z][a-z0-9_]*)')


def replace_gpcl(text: str) -> str:
    """소문자 gpcl_<name> → 대문자 GPCL_<NAME> 치환"""
    return PATTERN.sub(lambda m: 'GPCL_' + m.group(1).upper(), text)


def patch_jar_xml(jar_path: str) -> int:
    """
    JAR 내 모든 XML 파일에서 gpcl_ → GPCL_ 치환.
    Returns: 총 치환 건수 (0이면 변경 없음)
    """
    tmp_path = jar_path + '.patch_tmp'
    total_replacements = 0

    with zipfile.ZipFile(jar_path, 'r') as zin:
        with zipfile.ZipFile(tmp_path, 'w', zipfile.ZIP_DEFLATED) as zout:
            for info in zin.infolist():
                data = zin.read(info.filename)

                if info.filename.endswith('.xml'):
                    try:
                        original = data.decode('utf-8')
                        patched = replace_gpcl(original)
                        if patched != original:
                            count = len(PATTERN.findall(original))
                            total_replacements += count
                            print(f'[PATCHED] {info.filename}: {count} replacement(s)')
                            data = patched.encode('utf-8')
                    except UnicodeDecodeError:
                        pass  # 바이너리 파일은 건너뜀

                zout.writestr(info, data)

    # 성공하면 원본 교체
    shutil.move(tmp_path, jar_path)
    return total_replacements


def main():
    parser = argparse.ArgumentParser(description='Patch gpcl_ table names in JAR XML mappers')
    parser.add_argument('--jar', required=True, help='Path to the Spring Boot JAR file')
    args = parser.parse_args()

    if not os.path.isfile(args.jar):
        print(f'ERROR: JAR not found: {args.jar}')
        raise SystemExit(1)

    count = patch_jar_xml(args.jar)
    if count > 0:
        print(f'RESULT=changed total={count}')
    else:
        print('RESULT=unchanged')


if __name__ == '__main__':
    main()
