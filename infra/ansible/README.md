# infra/ansible — provisioning da VM `mgmt-api-vm`

Ansible é quem instala e configura tudo na VM do runtime da
`ecolchain-management-api` (criada pelo módulo
`infra/terraform/management-api-runtime`). O deploy das imagens em si é
**convergente**: a VM puxa novas tags do OCIR a cada 2 minutos via
`mgmt-pull.timer` (systemd), então nenhum inbound extra é necessário além
do SSH para esta configuração.

## Quem executa

O job `apply-prod` do `ci-terraform-apply.yml` roda este playbook
automaticamente depois de aplicar o módulo `management-api-runtime`:
extrai a chave SSH e as vars do `terraform output`, instala `ansible-core`
no runner e chama `playbooks/site.yml` via SSH (`opc@<ip>`).

## Uso local/manual

```bash
cd infra/terraform/management-api-runtime
terraform output -raw ssh_private_key > /tmp/mgmt_vm_key && chmod 600 /tmp/mgmt_vm_key
terraform output -json ansible_vars > /tmp/ansible_vars.json
terraform output -raw vm_public_ip   # <ip>

cd ../../ansible
ansible-playbook -i "<ip>," -u opc --private-key /tmp/mgmt_vm_key \
  --extra-vars "@/tmp/ansible_vars.json" playbooks/site.yml
```

## Estrutura

```
playbooks/
  site.yml     provisionamento completo (hardening + docker + ocir + app)
  dev.yml      só ambiente dev   (mgmt_envs=[dev])
  prod.yml     só ambiente prod  (mgmt_envs=[prod])
  runner.yml   self-hosted runner opcional (não usado pelo deploy)
roles/
  hardening    firewalld (app só via VCN), sshd sem senha, dnf-automatic
  docker       docker-ce + compose plugin + rotação de logs + grupo docker
  ocir         oci-cli p/ token de instance principal
  mgmt_app     /opt/mgmt-api: compose, env files, mgmt-pull.timer, smoke
  runner       actions-runner opcional (runner_url + runner_token)
```

## Variáveis (via `--extra-vars`)

O módulo Terraform exporta `ansible_vars` (output sensível) com tudo que
o playbook precisa — credenciais S3/SMTP, `OTP_PEPPER`, repo OCIR e as
credenciais estáticas de fallback do registry. Rodando manualmente,
monte um JSON equivalente (valores nos outputs `ansible_vars`,
`ocir_push_user`, `ocir_push_token`, `vm_public_ip`).

## Decisões (espelhadas em docs/DUVIDAS.md)

- **Deploy por polling** (`mgmt-pull.timer` + `docker compose pull`) —
  opção (c) do prompt na variante mais simples: sem ansible-pull nem
  runner para deploy. Login OCIR por instance principal; auth token
  estático é fallback.
- **Self-hosted runner** fica disponível (`playbooks/runner.yml`) mas
  fora do default — o deploy não depende dele.
- SSH :22 aberto para o Ansible do CD e operação manual (key-only);
  portas da app só respondem à VCN.
