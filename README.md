# subash-k8s-ecosystem

```
kubectl create namespace argocd
kubectl apply -n argocd -f manifests/argocd-install-manifest.yaml
# FOr latest

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo


#list versions
helm search repo ingress-nginx/ingress-nginx --versions

```

## Reserve to prevent ip duplication on K8S-loadbalancer and ec2

via command 

```bash
# Reserve IPs for your LoadBalancers
aws ec2 create-subnet-cidr-reservation \
  --subnet-id subnet-xxxxx \
  --cidr 172.17.20.128/26 \
  --reservation-type explicit \
  --description "Reserved for K8s LoadBalancers"
```
Via GUI
=========

Create a Subnet CIDR Reservation:
Option 1: Using AWS Console

Go to VPC Console → Subnets
Select your subnet
Click Actions → Edit CIDR reservations
Add IPv4 CIDR reservation:

Type: Explicit (for manual assignment like LoadBalancers)

172.17.20.128/26 (so 20.129 to 20.159) 16 ipsa are excluded

```

kubectl get pods -n metallb-system
sudo k8s set load-balancer.cidrs="172.17.20.129-172.17.20.159"
sudo k8s get load-balancer

```