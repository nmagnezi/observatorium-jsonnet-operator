local manifests = (import 'obs-operator.jsonnet').manifests;

{
  objects: {
    [item]: manifests[item] for item in std.objectFields(manifests)
  },
  rollout: {
   "apiVersion": "workflow.kubernetes.io/v1alpha1",
   "kind": "Rollout",
   "metadata": {
      "name": "jsonnet"
   },
   "spec": {
      "groups": [
         {
            "steps": [
               {
                  "action": "CreateOrUpdate",
                  "object": item
               }  for item in std.objectFields(manifests)
            ]
         }
      ]
   }
},
}
