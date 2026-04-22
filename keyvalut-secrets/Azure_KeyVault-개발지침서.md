# Azure Key Vault 연동 개발지침서

## 목적
- IWON_WALLET_AES_KEY_BASE64 값을 코드 저장소와 application.yml 기본값에서 제거한다.
- Azure Key Vault에 저장한 비밀값을 Azure DevOps 파이프라인에서 주입해 사용한다.

## 적용 대상
- src/main/resources/application.yml
- src/main/java/com/iwon/integration/service/AesGcmWalletAddressCrypto.java
- src/main/java/com/iwon/integration/config/IntegrationProperties.java

## 1. 소스 수정 기준

### 1-1. application.yml
- 대상 파일
  - src/main/resources/application.yml


- 변경 의도
  1. YAML 기본값에 비밀키값이 남으면 저장소 유출 시 즉시 보안사고로 이어질 수 있다.
  2. 실행 시점에만 환경변수로 주입되게 하여 비밀키값의 저장 위치를 Key Vault로 단일화한다.
  3. 운영/스테이징/개발 환경별로 Key Vault secret만 분리하면 동일한 배포 산출물을 재사용할 수 있다.

- 실제 소스 중 변경 대상 라인
~~~yaml
integration:
  wallet:
    crypto:
      aesKeyBase64: ${IWON_WALLET_AES_KEY_BASE64:YBZKoOzR6eRW/2ZBfcBxmiN5bDhzXptxHnue69U20+0=}
~~~

- 변경 전 (실제 코드 발췌)
~~~yaml
aesKeyBase64: ${IWON_WALLET_AES_KEY_BASE64:YBZKoOzR6eRW/2ZBfcBxmiN5bDhzXptxHnue69U20+0=}
~~~

- 변경 후 (가이드)
~~~yaml
# Inject from Azure Key Vault via Azure DevOps (do not hardcode defaults).
aesKeyBase64: ${IWON_WALLET_AES_KEY_BASE64:}
~~~


### 1-2. AesGcmWalletAddressCrypto.java
- 대상 파일
  - src/main/java/com/iwon/integration/service/AesGcmWalletAddressCrypto.java

- 실제 소스 중 변경 대상 메소드 1: encrypt(String plainWalletAddress)

- 변경 의도
  1. 운영자가 에러 메시지만 보고도 설정 키를 바로 식별할 수 있어야 한다.
  2. Spring 프로퍼티 키와 OS 환경변수 키를 동시에 표기해 장애 대응 시간을 줄인다.
   
변경 전 (실제 코드 발췌)
~~~java
@Override
public String encrypt(String plainWalletAddress) {
  if (plainWalletAddress == null) return null;
  if (secretKey == null) {
    throw new IllegalStateException("wallet encryption key is not configured (integration.wallet.crypto.aesKeyBase64)");
  }
  ...
}
~~~

변경 후 (가이드)
~~~java
@Override
public String encrypt(String plainWalletAddress) {
  if (plainWalletAddress == null) return null;
  if (secretKey == null) {
    throw new IllegalStateException(
      "wallet encryption key is not configured (integration.wallet.crypto.aesKeyBase64 / IWON_WALLET_AES_KEY_BASE64)"
    );
  }
  ...
}
~~~

- 실제 소스 중 변경 대상 메소드 2: decrypt(String encryptedWalletAddress)

변경 전 (실제 코드 발췌)
~~~java
@Override
public String decrypt(String encryptedWalletAddress) {
  ...
  if (secretKey == null) {
    throw new IllegalStateException("wallet decryption key is not configured (integration.wallet.crypto.aesKeyBase64)");
  }
  ...
}
~~~

변경 후 (가이드)
~~~java
@Override
public String decrypt(String encryptedWalletAddress) {
  ...
  if (secretKey == null) {
    throw new IllegalStateException(
      "wallet decryption key is not configured (integration.wallet.crypto.aesKeyBase64 / IWON_WALLET_AES_KEY_BASE64)"
    );
  }
  ...
}
~~~


### 1-3. IntegrationProperties.java
- 대상 파일
  - src/main/java/com/iwon/integration/config/IntegrationProperties.java

- 실제 소스 중 변경 대상 블록: Wallet.Crypto 내부 필드/메소드

- 변경 의도
  1. 소스 주석만 읽어도 비밀값 주입 경로가 Key Vault 기반임을 즉시 이해할 수 있어야 한다.
  2. 임시/로컬 암시 문구를 제거하고 운영 표준(외부 비밀관리)으로 표현을 일원화한다.
   
변경 전 (실제 코드 발췌)
~~~java
public static class Crypto {
  // Base64-encoded 32-byte AES key for temporary app-managed encryption.
  private String aesKeyBase64;

  public String getAesKeyBase64() {
    return aesKeyBase64;
  }

  public void setAesKeyBase64(String aesKeyBase64) {
    this.aesKeyBase64 = aesKeyBase64;
  }
}
~~~

변경 후 (가이드)
~~~java
public static class Crypto {
  // Base64-encoded 32-byte AES key.
  // Recommended source: Azure Key Vault secret mapped to IWON_WALLET_AES_KEY_BASE64.
  private String aesKeyBase64;

  public String getAesKeyBase64() {
    return aesKeyBase64;
  }

  public void setAesKeyBase64(String aesKeyBase64) {
    this.aesKeyBase64 = aesKeyBase64;
  }
}
~~~


## 2. Azure 설정 및 파이프라인 연동(데브옵스엔지니어에게 요청)

### 2.1 전달 항목

| 항목 | 값 | 예시 |
|------|-----|-----|
| Key Vault 이름 | 키값 | `iwonsvckvkrc001` |

> Azure Portal Secret 등록, RBAC 권한 설정, DevOps 파이프라인 연동, 검증 체크리스트, 보안 운영 원칙은 별도 문서를 참조한다.
>
> **참조 문서**: [AzurePortal_KeyVault_Secret_등록절차서.md](AzurePortal_KeyVault_Secret_등록절차서.md)
