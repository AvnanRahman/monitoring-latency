kubectl run -it --rm  --image=alpine --restart=Never --overrides='
{
  "spec": {
    "containers": [{
      "name": "pvc-helper",
      "image": "alpine",
      "command": ["/bin/sh"],
      "volumeMounts": [{
        "name": "pvc-script",
        "mountPath": "/data"
      }]
    }],
    "volumes": [{
      "name": "pvc-script",
      "persistentVolumeClaim": {
        "claimName": "pvc-script"
      }
    }]
  }
}' -- sh
