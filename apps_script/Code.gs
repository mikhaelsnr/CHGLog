const SHEET_NAME = 'ACTIVE';
const STATUS_COLUMN = 15; // Column O.
const LOGOUT_TIME_COLUMN = 17; // Column Q.
const CHG_COLUMN = 9; // Column I.
const TITLE_COLUMN = 2; // Column B.
const OBJECTIVE_COLUMN = 3; // Column C.
const LOGIN_TIME_COLUMN = 16; // Column P.
const DETAILS_COLUMN = 20; // Column T.
const PROPONENT_COLUMN = 21; // Column U.
const ALLOWED_STATUSES = new Set([
  'login',
  'ongoing pre-checks',
  'ongoing planned',
  'ongoing post-checks',
  'implemented',
]);

/**
 * Install this function as a spreadsheet "On edit" trigger.
 * Do not rename it to onEdit; it needs installable-trigger authorization.
 */
function handleStatusEdit(event) {
  if (!event || !event.range) return;

  const editedRange = event.range;
  const sheet = editedRange.getSheet();
  if (sheet.getName() !== SHEET_NAME) return;

  const firstColumn = editedRange.getColumn();
  const lastColumn = editedRange.getLastColumn();
  const includesStatus =
    STATUS_COLUMN >= firstColumn && STATUS_COLUMN <= lastColumn;
  const includesDetails =
    DETAILS_COLUMN >= firstColumn && DETAILS_COLUMN <= lastColumn;
  if (!includesStatus && !includesDetails) return;

  const properties = PropertiesService.getScriptProperties();
  const webhookUrl = properties.getProperty('CHGLOG_WEBHOOK_URL');
  const webhookSecret = properties.getProperty('CHGLOG_WEBHOOK_SECRET');
  if (!webhookUrl || !webhookSecret) {
    throw new Error('CHGLog webhook script properties are not configured.');
  }

  const firstRow = editedRange.getRow();
  const rowCount = editedRange.getNumRows();
  const statuses = sheet
    .getRange(firstRow, STATUS_COLUMN, rowCount, 1)
    .getDisplayValues();
  const changeCells = sheet
    .getRange(firstRow, CHG_COLUMN, rowCount, 1)
    .getDisplayValues();
  const titles = sheet
    .getRange(firstRow, TITLE_COLUMN, rowCount, 1)
    .getDisplayValues();
  const objectives = sheet
    .getRange(firstRow, OBJECTIVE_COLUMN, rowCount, 1)
    .getDisplayValues();
  const loginTimes = sheet
    .getRange(firstRow, LOGIN_TIME_COLUMN, rowCount, 1)
    .getDisplayValues();
  const details = sheet
    .getRange(firstRow, DETAILS_COLUMN, rowCount, 1)
    .getDisplayValues();
  const proponents = sheet
    .getRange(firstRow, PROPONENT_COLUMN, rowCount, 1)
    .getDisplayValues();

  for (let offset = 0; offset < rowCount; offset += 1) {
    const status = normalizeStatus_(statuses[offset][0]);
    if (!ALLOWED_STATUSES.has(status)) continue;

    const logoutCell = sheet.getRange(
      firstRow + offset,
      LOGOUT_TIME_COLUMN,
    );
    const existingLogoutTime = String(
      logoutCell.getDisplayValue() || '',
    ).trim();
    const logoutTime = status === 'implemented'
      ? (/^\d{4}H$/.test(existingLogoutTime)
          ? existingLogoutTime
          : Utilities.formatDate(new Date(), 'Asia/Manila', 'HHmm') + 'H')
      : '';
    if (includesStatus) logoutCell.setValue(logoutTime);

    const changeNumbers = String(changeCells[offset][0] || '')
      .toUpperCase()
      .match(/\bCHG\d{7}\b/g) || [];

    sendStatusUpdate_(webhookUrl, webhookSecret, {
      sheetName: SHEET_NAME,
      editType: includesStatus ? 'status' : 'details',
      rowNumber: firstRow + offset,
      status: status,
      logoutTime: logoutTime,
      changeNumbers: [...new Set(changeNumbers)],
      title: String(titles[offset][0] || '').trim(),
      objective: String(objectives[offset][0] || '').trim(),
      proponent: String(proponents[offset][0] || '').trim(),
      loginTime: String(loginTimes[offset][0] || '').trim(),
      details: String(details[offset][0] || '').trim(),
      editedBy: event.user ? String(event.user.getEmail() || '').trim() : '',
      editedAt: new Date().toISOString(),
    });
  }
}

function normalizeStatus_(value) {
  return String(value || '').trim().toLowerCase().replace(/\s+/g, ' ');
}

function sendStatusUpdate_(url, secret, payload) {
  const response = UrlFetchApp.fetch(url, {
    method: 'post',
    contentType: 'application/json',
    headers: {'X-CHGLog-Webhook-Secret': secret},
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });

  const statusCode = response.getResponseCode();
  if (statusCode < 200 || statusCode >= 300) {
    throw new Error(
      `CHGLog webhook returned ${statusCode}: ${response.getContentText()}`,
    );
  }
}
