# Roadmap

This document describes upcoming releases and planned features/enhancements.
Gitv has a tentative 6 month release schedule, depending on availability.

<table>
  <tbody>
    <tr>
      <th>Version</th>
      <th>Goals</th>
      <th>Features</th>
    </tr>
    <tr>
      <td><s>1.3.1</s> (complete)</td>
      <td>Incorporate new features present in other branch viewers and fix long standing bugs</td>
      <td>
        <ul>
          <li>Implement bisecting directly inside the plugin</li>
          <li>Implement rebasing directly inside the plugin</li>
          <li>Add robust key remapping</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td>1.4 (<i>stable</i>, <b>pending testing</b>)</td>
      <td>Improve stability of new features and incorporate community feedback</td>
      <td>
        <ul>
          <li>Fixes for broken/duplicate bindings</li>
          <li>More binding name consistency</li>
          <li>Better rebasing/bisecting documentation</li>
          <li>Better bisecting UX ("next" only targets cursor on visual selection)</li>
          <li>Fixed custom split directions breaking certain functions (split direction is hardcoded until 1.4.1 or later) - thanks to @synic</li>
          <li>Added helper to get debugging information</li>
          <li>Added rudamentary neovim support - thanks to the Neovim team</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td>1.4.1</td>
      <td>Improve window system</td>
      <td>
        <ul>
          <li>Reworked window creation and switching system</li>
          <li>Configurable window layout</li>
          <li>Reduced layout mangling in browser mode</li>
          <li>Stable preview window functionality</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td>1.4.2</td>
      <td>Improve command running and output</td>
      <td>
        <ul>
          <li>Reworked git command running system</li>
          <li>Improved error output</li>
          <li>New informational output system</li>
          <li>Better compatibility with neovim's new command running system</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td>1.5 (<i>stable</i>)</td>
      <td>Improve stability of the reworked features and incorporate community feedback</td>
      <td><i>Pending community feedback</i></td>
    </tr>
    <tr>
      <td>1.5.1</td>
      <td>Improve customizability and function of the preview window</td>
      <td>
        <ul>
          <li>Reworked preview window creation system</li>
          <li>Customizable preview formatting</li>
          <li>More kinds of preview window output</li>
          <li>Preview window binding and settings system</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td>1.5.2</td>
      <td>Improve customizability of log formatting</td>
      <td>
        <ul>
          <li>Reworked ref/commit retrieval system</li>
          <li>Reworked log format parsing system</li>
        </ul>
      </td>
    </tr>
    <tr>
      <td>1.6 (<i>stable</i>)</td>
      <td>Improve stability of new customizable systems and incorporate community feedback</td>
      <td><i>Pending community feedback</i></td>
    </tr>
  </tbody>
</table>
