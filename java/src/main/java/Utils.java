
public class Utils {

    /**
     * Logs progress to console
     */
    public static void progress(long count, long startTime, long contentLength, long bytesRead, int every) {
        if (count % every != 0) return;

        double elapsedSeconds = (System.currentTimeMillis() - startTime) / 1000.0;
        long rate = elapsedSeconds > 0 ? Math.round(count / elapsedSeconds) : 0;
        
        StringBuilder msg = new StringBuilder();
        msg.append(String.format("Inserted %d docs (%d docs/sec)", count, rate));

        if (contentLength > 0 && bytesRead > 0) {
            double pct = (double) bytesRead / contentLength;
            long remaining = pct > 0 ? Math.round((elapsedSeconds / pct) - elapsedSeconds) : 0;
            msg.append(String.format(" | %.1f%% done, ~%ds remaining", pct * 100, remaining));
        }

        System.out.println(msg.toString());
    }
}