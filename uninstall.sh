#/usr/bin/env bash

helm -n argocd uninstall argocd-apps
helm -n argocd uninstall argo-cd
kubectl delete crd appprojects.argoproj.io --force
kubectl delete crd applicationsets.argoproj.io --force
kubectl delete crd applications.argoproj.io --force
kubectl delete ns argocd --force
tofu state rm helm_release.argo-cd
tofu state rm helm_release.argocd-apps
