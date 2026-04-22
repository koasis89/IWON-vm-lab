az keyvault secret set --vault-name iwonsvckvkrc001 --name IWON-WALLET-AES-KEY-BASE64 --value "YBZKoOzR6eRW/2ZBfcBxmiN5bDhzXptxHnue69U20+0=" --only-show-errors 1>nul


az keyvault secret set --vault-name iwonsvckvkrc001 --name IWON-WALLET-AES-KEY-BASE64 --value "YBZKoOzR6eRW/2ZBfcBxmiN5bDhzXptxHnue69U20+0="

az keyvault secret set --vault-name iwonsvckvkrc001 --name IWON-WALLET-AES-KEY-BASE64 --value "YBZKoOzR6eRW/2ZBfcBxmiN5bDhzXptxHnue69U20+0="

## 3. Secret 등록 결과 검증 (변수등록시 재수행)

~~~powershell
az keyvault secret show --vault-name iwonsvckvkrc001 --name IWON-WALLET-AES-KEY-BASE64 --query "{name:name,enabled:attributes.enabled,updated:attributes.updated,id:id}" -o json
~~~

