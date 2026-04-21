# Configuration
SUBJECT_PREFIX="Cost Anomaly Alert"
START_DATE=$(date -u +"%Y-%m-%dT00:00:00Z")
END_DATE=$(date -u -d "+1 year" +"%Y-%m-%dT00:00:00Z")
# Counters
created=0
skipped=0
failed=0
# Get all enabled subscriptions
subscriptions=$(az account list --query "[?state=='Enabled'].[id, displayName]" -o tsv)
while IFS=$'\t' read -r sub_id sub_name; do
    echo "Processing: $sub_name ($sub_id)"
    # Fetch Contactdl tag from the subscription
    contact_email=$(az tag list \
        --resource-id "/subscriptions/${sub_id}" \
        --query "properties.tags.Contactdl" \
        -o tsv 2>/dev/null)
    # Skip if no Contactdl tag
    if [ -z "$contact_email" ] || [ "$contact_email" == "None" ]; then
        echo "  SKIPPED - no 'Contactdl' tag found"
        ((skipped++))
        continue
    fi
    echo "  Email: $contact_email"
    az costmanagement scheduled-action create \
        --name "cost-anomaly-alert-${sub_id}" \
        --display-name "${SUBJECT_PREFIX} - ${sub_name}" \
        --kind "InsightAlert" \
        --scope "/subscriptions/${sub_id}" \
        --status "Enabled" \
        --view-id "/subscriptions/${sub_id}/providers/Microsoft.CostManagement/views/ms:DailyCosts" \
        --notification-email "$contact_email" \
        --notification-subject "${SUBJECT_PREFIX} - ${sub_name}" \
        --schedule-frequency "Daily" \
        --schedule-start-date "$START_DATE" \
        --schedule-end-date "$END_DATE" \
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
