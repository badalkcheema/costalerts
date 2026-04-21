#!/bin/bash

START_DATE=$(date -u +"%Y-%m-%dT00:00:00Z")
END_DATE=$(date -u -d "+1 year" +"%Y-%m-%dT00:00:00Z")
SUBJECT_PREFIX="Cost Anomaly Alert"

created=0
skipped=0
failed=0

subscriptions=$(az account list --query "[?state=='Enabled'].[id, displayName]" -o tsv)

while IFS=$'\t' read -r sub_id sub_name; do
    echo "Processing: $sub_name ($sub_id)"

    contact_email=$(az tag list \
        --resource-id "/subscriptions/${sub_id}" \
        --query "properties.tags.Contactdl" \
        -o tsv 2>/dev/null)

    if [ -z "$contact_email" ] || [ "$contact_email" == "None" ]; then
        echo "  SKIPPED - no 'Contactdl' tag found"
        ((skipped++))
        continue
    fi

    echo "  Email: $contact_email"

    az rest --method PUT \
        --uri "https://management.azure.com/subscriptions/${sub_id}/providers/Microsoft.CostManagement/scheduledActions/cost-anomaly-alert-${sub_id}?api-version=2023-11-01" \
        --body "{
            \"kind\": \"InsightAlert\",
            \"properties\": {
                \"displayName\": \"${SUBJECT_PREFIX} - ${sub_name}\",
                \"status\": \"Enabled\",
                \"viewId\": \"/subscriptions/${sub_id}/providers/Microsoft.CostManagement/views/ms:DailyCosts\",
                \"notification\": {
                    \"to\": [\"${contact_email}\"],
                    \"subject\": \"${SUBJECT_PREFIX} - ${sub_name}\"
                },
                \"schedule\": {
                    \"frequency\": \"Daily\",
                    \"startDate\": \"${START_DATE}\",
                    \"endDate\": \"${END_DATE}\"
                }
            }
        }" \
        -o none

    if [ $? -eq 0 ]; then
        echo "  SUCCESS - alert created"
        ((created++))
    else
        echo "  FAILED - could not create alert"
        ((failed++))
    fi

done <<< "$subscriptions"

echo ""
echo "=============================="
echo "Summary:"
echo "  Created: $created"
echo "  Skipped: $skipped (no Contactdl tag)"
echo "  Failed:  $failed"
echo "=============================="
