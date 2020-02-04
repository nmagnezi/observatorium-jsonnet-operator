local manifests = (import 'observatorium.jsonnet').manifests;

{
  objects: {
    [item]: manifests[item] for item in std.objectFields(manifests)
  },
  rollout: {
   "apiVersion": "v1",
   "kind": "ConfigMap",
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
