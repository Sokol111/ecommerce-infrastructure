# kubectl Cheatsheet

## Підключення до production (Hetzner k3s)

```bash
# Дефолтний kubeconfig вказує на локальний кластер (k3d).
# Для production потрібно вказати правильний kubeconfig:
export KUBECONFIG=~/.kube/config-hetzner

# Або додавати перед кожною командою:
KUBECONFIG=~/.kube/config-hetzner kubectl get pods -n prod

# Через Makefile KUBECONFIG встановлюється автоматично.
# Перед роботою переконайся що SSH тунель відкритий:
make tunnel
```

## Статус подів

```bash
kubectl get pods -n prod                          # всі поди
kubectl get pods -n prod -o wide                   # + IP, нода
kubectl get pods -n prod -w                        # watch в реальному часі
```

## Деталі пода (events, причини крашів, image pull помилки)

```bash
kubectl describe pod <pod-name> -n prod
kubectl describe pod <pod-name> -n prod | tail -20  # тільки events
kubectl describe pod -n prod -l app.kubernetes.io/name=ecommerce-auth-service  # по лейблу (не треба знати ім'я)
```

## Логи

```bash
kubectl logs <pod-name> -n prod                    # поточні логи
kubectl logs <pod-name> -n prod --tail=50          # останні 50 рядків
kubectl logs <pod-name> -n prod -f                 # follow (live)
kubectl logs <pod-name> -n prod -p                 # логи попереднього контейнера (після краша)
kubectl logs <pod-name> -n prod -c <container>     # конкретний контейнер (якщо >1)
```

По лейблу (не треба знати ім'я пода):

```bash
kubectl logs -n prod -l app.kubernetes.io/name=ecommerce-auth-service --tail=50
```

## Exec в контейнер

```bash
kubectl exec -it <pod-name> -n prod -- sh          # shell
kubectl exec <pod-name> -n prod -- env             # змінні оточення
kubectl exec <pod-name> -n prod -- cat /configs/config.yaml
```

## Ресурси

```bash
kubectl top pods -n prod                           # CPU/RAM по подах
kubectl top nodes                                  # CPU/RAM по нодах
```

## Helm

```bash
helm list -n prod                                  # встановлені релізи
helm history <release> -n prod                     # історія деплоїв
helm get values <release> -n prod                  # поточні values
```

## Швидка діагностика CrashLoopBackOff

```bash
# 1. Причина краша
kubectl logs <pod> -n prod -p --tail=30
# 2. Events (ImagePull, OOM, проби)
kubectl describe pod <pod> -n prod | grep -A20 Events
# 3. Exit code
kubectl get pod <pod> -n prod -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
```

## Port-forward для локального доступу

```bash
kubectl port-forward -n prod svc/<service> 8080:8080
```
