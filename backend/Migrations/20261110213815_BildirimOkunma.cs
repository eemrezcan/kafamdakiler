using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kafamdakiler.Migrations
{
    /// <inheritdoc />
    public partial class BildirimOkunma : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "OkunmaAni",
                table: "Bildirimler",
                type: "timestamp with time zone",
                nullable: true);

            // What was sent before the center existed was shown on the phone already: it starts as read, so the unread count starts at zero.
            migrationBuilder.Sql("UPDATE \"Bildirimler\" SET \"OkunmaAni\" = \"OlusmaAni\";");

            migrationBuilder.CreateIndex(
                name: "IX_Bildirimler_KullaniciId_OlusmaAni",
                table: "Bildirimler",
                columns: new[] { "KullaniciId", "OlusmaAni" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Bildirimler_KullaniciId_OlusmaAni",
                table: "Bildirimler");

            migrationBuilder.DropColumn(
                name: "OkunmaAni",
                table: "Bildirimler");
        }
    }
}
