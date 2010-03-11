<h2>Hawk Commercial Web Interface ver. 0.0.1</h2>
<hr>
Menu: <a href="?action=listbroots">list broots</a> | <a href="?action=summery"> summery reports </a><br />
Menu: <a href="?action=listfailed"> list failed </a> | <a href="?action=summery"> summery reports </a><br />
Menu: <a href="?action=listbroots">list broots</a> | <a href="?action=listfailed"> list failed </a><br />
<hr>


Failed attempts by hour(last 24 hours only):<br />
<table>
<tr>
  <td><a href="?action=listfailed&order=0">Date</a></td>
  <td><a href="?action=listfailed&order=1">IP Address</td>
  <td><a href="?action=listfailed&order=2">Service</td>
  <td><a href="?action=listfailed&order=3">User</td>
</tr>
<tr><td>01-01-2000 00:00</td><td>IP</td><td>SERVICE</td><td>USER</td></tr>
</table>



Brootforce attempts by hour(last 56 hours only):<br />
<table>
<tr>
  <td><a href="?action=listbroots&order=0">Date</a></td>
  <td><a href="?action=listbroots&order=1">IP Address</td>
  <td><a href="?action=listbroots&order=2">Service</td>
</tr>
<tr><td>01-01-2000 00:00</td><td>IP</td><td>SERVICE</td></tr>
</table>



Summery by date(for the last 7 days only):<br />
<table>
<tr><td>Date</td><td>All failed attempts</td><td>All brootforce attempts</td></tr>
<tr><td>01-01-2000</td><td>0</td><td>1</td></tr>
</table>
Summery by service:<br />
<table>
<tr><td>SSH</td><td>FTP</td><td>POP3</td><td>IMAP</td><td>cPanel</td></tr>
<tr><td>0</td><td>1</td><td>1</td><td>1</td><td>1</td></tr>
</table>

