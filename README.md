- Create file `terraform.tfvars`:
```
cloud_id  = "<value>"
folder_id = "<value>"
tg_bot_key = "<value>"
service_account_api_key = "<value>"
service_account_id = "<value>"
instructions_bucket_name = "<value>"
instructions_bucket_key = "<value>"
```

- Zip code:
```
zip function.zip index.py
```

- Run Terraform:
```
terraform apply
```
